# Build e deploy

Guida operativa per pubblicare il backend su una VPS e compilare e firmare l'app Flutter.

## Architettura in produzione

```text
              Internet: 443 (https), 80 (solo redirect a https)
                                 │
     VPS alex-violatto (83.228.220.189, Ubuntu, alias SSH alex-violatto)
                                 │
                Caddy di sistema (/etc/caddy/Caddyfile)
           ┌─────────────────────┴──────────────────────┐
  git.alexviolatto.dev               financialmanager.alexviolatto.dev
  (git self-hosted)                    │                          │
                              /api/*  (senza /api)          tutto il resto
                                       │                          │
                              127.0.0.1:10003          /var/www/financialmanager
                              container api             (dashboard web; per ora
                                       │                  pagina segnaposto)
                         rete Docker backend_internal
               postgres · redis · object-storage (MinIO) · worker
```

- Il progetto è in `/projects/FinancialManager` sulla VPS `alex-violatto`. Fino a ottobre 2026 il backend girava sulla VPS `remote-viewer` (`http://83.228.246.84:10003`), che ora resta dedicata a RemoteViewer: lo spostamento è descritto nella sezione 10.
- Su Internet è esposto solo Caddy. L'API è pubblicata sull'host solo su `127.0.0.1:10003`; PostgreSQL, Redis e MinIO sono raggiungibili solo sulla rete interna di Docker.
- L'app usa `https://financialmanager.alexviolatto.dev/api/v1`: Caddy toglie il prefisso `/api`, quindi il backend continua a esporre `/v1/...` e `/health/...` come in locale.
- La dashboard web (il sottodominio senza `/api`) non è ancora implementata: la build Flutter web è un lavoro separato. Quando ci sarà, basterà copiare il contenuto di `build/web` in `/var/www/financialmanager`; stando sullo stesso dominio dell'API non servirà configurare CORS.

## Backend su VPS

Il backend e' un'app Go eseguita via Docker Compose con PostgreSQL, Redis e MinIO. I file principali sono:

- `financial-manager-backend/compose.yaml`
- `financial-manager-backend/compose.prod.yaml`
- `financial-manager-backend/.env.example`
- `financial-manager-backend/Dockerfile`
- `financial-manager-backend/deploy/Caddyfile.example` (il blocco del sito per Caddy)

### 1. Preparare la VPS

Sulla VPS devono essere installati:

- Docker Engine e il plugin Docker Compose, dal repository ufficiale di Docker
- Git
- Caddy (sulla VPS attuale è già installato come servizio di sistema)
- OpenSSL, utile per generare segreti

Installazione di Docker su Ubuntu (dalla guida ufficiale, docs.docker.com/engine/install/ubuntu):

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"   # poi uscire e rientrare in SSH
```

La VPS ha 2 GB di RAM e nessuna swap di serie: la build delle immagini Go e lo stack completo (PostgreSQL, Redis, MinIO, api, worker) ci stanno stretti. Aggiungere una swap da 2 GB:

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
free -h   # la riga Swap mostra 2.0Gi
```

Clonare il repository in `/projects/FinancialManager`:

```bash
sudo mkdir -p /projects && sudo chown "$USER" /projects
git clone <url-del-repository> /projects/FinancialManager
```

Firewall: verso Internet servono solo le porte 22 (SSH), 80 e 443 (Caddy). La porta `10003` non va aperta: l'API ascolta solo su `127.0.0.1`. Controllare sia il firewall del provider della VPS sia `ufw`, se attivo (`sudo ufw status`).

### 2. Creare il file `.env`

Entrare nella cartella backend:

```bash
cd /projects/FinancialManager/financial-manager-backend
cp .env.example .env
```

Se si sposta un'installazione esistente, copiare invece il `.env` della vecchia VPS (sezione 10): i segreti devono restare gli stessi, altrimenti le sessioni vengono invalidate, le chiavi API degli utenti non si decifrano più e i backup già fatti non si aprono.

Modificare `.env` con valori di produzione. Le variabili piu' importanti sono:

```env
APP_ENV=production

POSTGRES_USER=financial_manager
POSTGRES_PASSWORD=CAMBIA_CON_PASSWORD_FORTE
POSTGRES_DB=financial_manager

REDIS_PASSWORD=CAMBIA_CON_PASSWORD_FORTE

OBJECT_STORAGE_BUCKET=financial-manager-media
OBJECT_STORAGE_ACCESS_KEY=financial_manager
OBJECT_STORAGE_SECRET_KEY=CAMBIA_CON_PASSWORD_FORTE
OBJECT_STORAGE_USE_SSL=false

JWT_SIGNING_KEY=CAMBIA_CON_CHIAVE_RANDOM_LUNGA
ACCESS_TOKEN_TTL=15m
REFRESH_TOKEN_TTL=720h

GOOGLE_CLIENT_IDS=394336083524-bulv3lv21sl2jl1gkrjnad25i7qvgv1v.apps.googleusercontent.com

IMAGE_SEARCH_PROVIDER=stub
IMAGE_SEARCH_API_KEY=

# Dietro Caddy sullo stesso host: API solo su loopback
API_HOST_BIND=127.0.0.1
API_HOST_PORT=10003
# Caddy raggiunge il container dalla rete bridge di Docker
TRUSTED_PROXY_CIDRS=172.16.0.0/12

BACKUP_ENCRYPTION_KEY=CAMBIA_CON_CHIAVE_RANDOM_LUNGA
GDRIVE_CLIENT_ID=xxxxxxxx.apps.googleusercontent.com
GDRIVE_CLIENT_SECRET=CAMBIA
GDRIVE_REFRESH_TOKEN=CAMBIA

# Facoltativo: abilita l'Analisi AI con fornitori cloud (vedi sezione 8)
AI_KEY_ENCRYPTION_KEY=CAMBIA_CON_OPENSSL_RAND_BASE64_32
# Analisi AI sul dispositivo (vedi sezione 9): attiva di default
AI_ON_DEVICE_ENABLED=true
```

Generare `JWT_SIGNING_KEY` e `BACKUP_ENCRYPTION_KEY` (due valori diversi) con:

```bash
openssl rand -base64 48
```

In produzione `JWT_SIGNING_KEY`, `OBJECT_STORAGE_ACCESS_KEY` e `OBJECT_STORAGE_SECRET_KEY` sono obbligatori.

`GOOGLE_CLIENT_IDS` contiene il client OAuth di tipo **Applicazione web**, lo stesso che l'app usa come `serverClientId` in `lib/core/auth/google_sign_in_service.dart`: il backend accetta solo ID token di Google emessi per quel client. Non cambia quando cambia la chiave di firma dell'app (vedi "Firma Android").

**`API_HOST_BIND` e `TRUSTED_PROXY_CIDRS`.** `compose.prod.yaml` pubblica solo l'API, su `API_HOST_BIND:API_HOST_PORT`. Con Caddy sullo stesso host si usa `127.0.0.1`, così la porta `10003` non è raggiungibile da fuori e tutto il traffico passa in HTTPS. Caddy però si collega al container attraverso il bridge di Docker, quindi per il backend ogni richiesta arriverebbe da un indirizzo `172.x`. `TRUSTED_PROXY_CIDRS` (CIDR o IP separati da virgola) dice al backend di quali indirizzi fidarsi: solo per le richieste che arrivano da lì legge l'IP reale del client dall'header `X-Forwarded-For` che Caddy aggiunge, prendendo l'indirizzo non fidato più a destra (quelli più a sinistra li scrive il client e vengono ignorati). Così `r.RemoteAddr` contiene l'IP del client per tutto il codice che lo usa. Oggi nessun dato lo salva: il login con password ne calcola un'impronta (`clientIPHash`) che però non viene registrata, e la colonna `sessions.ip_hash` resta vuota; la configurazione serve perché i log o le funzioni future basate sull'IP vedano quello vero e non `172.x`. Lasciarla vuota se l'API è raggiungibile direttamente, e non metterci mai indirizzi da cui può collegarsi chiunque, altrimenti ognuno potrebbe falsificare il proprio IP. Un valore malformato blocca l'avvio con un errore chiaro.

In produzione il backup automatico su Google Drive e' attivo di default: senza `BACKUP_ENCRYPTION_KEY` e le tre variabili `GDRIVE_*` il backup non viene eseguito e il `worker` registra `backup_not_configured` nei log a ogni controllo orario, mentre gli altri job continuano a funzionare normalmente. Come ottenerle e' spiegato in `financial-manager-backend/docs/backup-restore.md` (sezione "Off-site backups to Google Drive"). Per disattivarlo esplicitamente: `BACKUP_ENABLED=false`. Conservare una copia di `BACKUP_ENCRYPTION_KEY` fuori dalla VPS (es. password manager): senza, i backup su Drive non si possono decifrare.

### 3. DNS e HTTPS

**DNS.** Nel pannello del registrar di `alexviolatto.dev` aggiungere:

| Tipo | Nome | Valore |
|---|---|---|
| `A` | `financialmanager` | `83.228.220.189` |
| `AAAA` | `financialmanager` | `2001:1600:18:20c::23f` |

Il record `AAAA` va aggiunto solo se la VPS accetta connessioni IPv6 in ingresso sulle porte 80 e 443: un `AAAA` che non risponde rallenta o rompe la connessione per chi ha IPv6. Nel dubbio, solo il record `A`. Per controllare la propagazione:

```bash
nslookup financialmanager.alexviolatto.dev
```

Il dominio `.dev` è nella lista HSTS precaricata dei browser, quindi si raggiunge solo in HTTPS. Non è un problema, perché Caddy ottiene il certificato da solo.

**Caddy.** Caddy è installato come servizio di sistema e serve già `git.alexviolatto.dev`. Aggiungere a `/etc/caddy/Caddyfile`, sotto il blocco esistente, il contenuto di `financial-manager-backend/deploy/Caddyfile.example`:

```caddyfile
financialmanager.alexviolatto.dev {
	header Strict-Transport-Security "max-age=31536000; includeSubDomains"

	handle_path /api/* {
		respond /metrics* 404

		reverse_proxy 127.0.0.1:10003 {
			flush_interval -1
		}
	}

	handle {
		root * /var/www/financialmanager
		try_files {path} /index.html
		file_server
	}
}
```

Cosa fa ogni parte:

- `Strict-Transport-Security`: i client ricordano per un anno di usare solo HTTPS (plan.md sezione 19.3);
- `/api/metrics` risponde 404: il backend espone le metriche Prometheus su `/metrics` senza autenticazione e non devono essere pubbliche (plan.md sezione 22.1). La regola sta **dentro** `handle_path`, dove il prefisso `/api` è già stato tolto (quindi `/metrics*`): Caddy esegue `handle_path` prima di `respond`, e un `respond` messo fuori dal blocco non verrebbe mai applicato;
- `handle_path /api/*` inoltra all'API togliendo `/api` (`/api/v1/me` → `/v1/me`, `/api/health/ready` → `/health/ready`) e aggiunge `X-Forwarded-For`. `flush_interval -1` serve allo streaming delle analisi AI (sezione 8);
- `handle` serve i file statici della dashboard; `try_files` rimanda a `index.html` i percorsi che non sono file, così le route dell'app web funzioneranno anche ricaricando la pagina.

Creare la pagina segnaposto e ricaricare Caddy:

```bash
sudo mkdir -p /var/www/financialmanager
echo '<!doctype html><meta charset="utf-8"><title>Financial Manager</title><p>Financial Manager: dashboard in arrivo.</p>' \
  | sudo tee /var/www/financialmanager/index.html
sudo caddy validate --config /etc/caddy/Caddyfile
sudo systemctl reload caddy
```

Appena il DNS punta alla VPS, Caddy ottiene il certificato Let's Encrypt e lo rinnova da solo; le richieste in `http` vengono rimandate a `https`. In caso di problemi: `sudo journalctl -u caddy -f`.

**Senza reverse proxy** (sconsigliato): `API_HOST_BIND=0.0.0.0`, `TRUSTED_PROXY_CIDRS` vuota, porta `10003` aperta sul firewall e app compilata con `--dart-define=API_BASE_URL=http://IP_DELLA_VPS:10003/v1`. Le build release però non accettano più `http` (il manifest non permette traffico in chiaro), quindi così funzionano solo le build debug.

### 4. Avviare lo stack production

Dalla cartella `financial-manager-backend`:

```bash
docker compose -f compose.yaml -f compose.prod.yaml up -d --build
```

Il compose avvia:

- `postgres`
- `redis`
- `object-storage`
- `migrate`
- `api`
- `worker`

Il servizio `migrate` applica le migrazioni SQL prima dell'avvio dell'API e del worker. Sulla VPS da 1 vCPU la prima build delle immagini richiede alcuni minuti.

**Immagine di MinIO.** `object-storage` usa `dokjolly/minio:RELEASE.2025-10-15T17-29-55Z-r1`, non `minio/minio`. Da ottobre 2025 MinIO Inc. non pubblica più le immagini della versione community; in seguito le ha tolte da Docker Hub (`docker pull minio/minio` risponde "pull access denied") e ha chiuso i download anonimi da quay.io, e il progetto open source è archiviato. Un deploy da zero con `minio/minio:latest` oggi fallisce; funzionava solo dove l'immagine era già in cache.

L'immagine `dokjolly/minio` è l'ultima release di MinIO (2025-10-15) ricompilata dal sorgente nel repository [github.com/Dokjolly0/minio](https://github.com/Dokjolly0/minio) (copia anche su `git.alexviolatto.dev/Dokjolly/minio`), che contiene il sorgente, i Dockerfile e un workflow che pubblica su Docker Hub. Allo stesso modo `dokjolly/mc` sostituisce `minio/mc` negli script di backup. Le immagini usano lo stesso formato dei dati della vecchia `minio/minio:RELEASE.2025-09-07`, lo stesso entrypoint e le stesse variabili: il volume `object_storage_data` si usa così com'è.

- Usare sempre il tag con la revisione (`-r1`, `-r2`, ...): non cambia mai dopo la pubblicazione. `latest` e il tag senza revisione seguono l'ultima build.
- Per aggiornarla (Go, immagine base, dipendenze con correzioni di sicurezza) si segue il README di quel repository, si pubblica una nuova revisione e si cambia il tag in `compose.yaml` (e `MC_IMAGE` in `scripts/backup.sh` per il client).
- MinIO non riceverà più correzioni nel proprio codice. Qui è accettabile perché è raggiungibile solo dalla rete interna di Docker; nel lungo periodo si può valutare uno storage compatibile S3 ancora mantenuto (vedi "Cose da sistemare").

### 5. Verificare il deploy

Controllare i container:

```bash
docker compose -f compose.yaml -f compose.prod.yaml ps
```

Controllare i log:

```bash
docker compose -f compose.yaml -f compose.prod.yaml logs -f api
```

Controllare che il backup su Google Drive sia partito (`backup_ok` al primo avvio, poi `backup_skipped_not_due` finche' non passano 24h):

```bash
docker compose -f compose.yaml -f compose.prod.yaml logs worker | grep backup
```

Verificare l'health check, prima sulla VPS e poi da fuori attraverso Caddy:

```bash
curl http://127.0.0.1:10003/health/ready
curl https://financialmanager.alexviolatto.dev/api/health/ready
```

Altri controlli da un PC esterno:

```bash
curl -I http://financialmanager.alexviolatto.dev/               # redirect (308) a https
curl -I https://financialmanager.alexviolatto.dev/api/metrics   # 404
curl -m 5 http://83.228.220.189:10003/health/ready              # deve fallire: porta non esposta
```

L'API espone le route applicative sotto `/v1`, quindi l'app Flutter deve puntare a:

```text
https://financialmanager.alexviolatto.dev/api/v1
```

È il default delle build `production` (vedi "Build Flutter").

### 6. Aggiornare il backend dopo modifiche

Sulla VPS:

```bash
cd /projects/FinancialManager
git pull
cd financial-manager-backend
docker compose -f compose.yaml -f compose.prod.yaml up -d --build
```

Se vuoi forzare il rebuild senza cache:

```bash
docker compose -f compose.yaml -f compose.prod.yaml build --no-cache
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

Le migrazioni nuove vengono applicate dal servizio `migrate` a ogni `up`. Caddy non va toccato, salvo modifiche a `deploy/Caddyfile.example` da riportare a mano in `/etc/caddy/Caddyfile` (poi `sudo systemctl reload caddy`).

### 7. Backup

Il backend include script in:

```text
financial-manager-backend/scripts/
```

Documentazione specifica:

```text
financial-manager-backend/docs/backup-restore.md
```

Il `worker` carica ogni giorno su Google Drive un dump cifrato del database (storico: 30 giornalieri + 12 mensili) e un archivio cifrato delle immagini (rotazione `latest`/`previous`). Gli script in `scripts/` restano utili per una copia locale aggiuntiva e per il restore. Redis non viene incluso perche' contiene cache/rate limit/idempotency temporanea, non dati finanziari sorgente.

### 8. Analisi AI

L'Analisi AI usa le chiavi API che ogni utente inserisce nell'app; il server non ha una chiave propria. Per abilitarla serve solo `AI_KEY_ENCRYPTION_KEY`, la chiave con cui il server cifra le chiavi API degli utenti. Deve essere di esattamente 32 byte in base64:

```bash
openssl rand -base64 32
```

Senza questa variabile il backend parte normalmente e l'app mostra la funzione come non disponibile. Un valore malformato invece blocca l'avvio. Conservarne una copia fuori dalla VPS: se va persa, ogni utente deve reinserire la propria chiave API.

Per cambiarla senza far reinserire le chiavi:

1. spostare il valore attuale in `AI_KEY_ENCRYPTION_KEY_PREVIOUS`;
2. mettere il nuovo valore in `AI_KEY_ENCRYPTION_KEY`;
3. riavviare. Ogni chiave viene ricifrata con la nuova al primo utilizzo.

Il container `api` deve poter raggiungere Internet in uscita (HTTPS verso i fornitori).

**Reverse proxy.** Le analisi arrivano all'app in streaming (Server-Sent Events) e possono durare alcuni minuti. Il proxy non deve bufferizzare la risposta e non deve chiudere la connessione prima di `AI_STREAM_MAX_DURATION` (5 minuti di default):

- Caddy (la configurazione in produzione, sezione 3): `reverse_proxy 127.0.0.1:10003 { flush_interval -1 }`, già presente in `deploy/Caddyfile.example`. Caddy non ha un timeout di lettura di default.
- Nginx, se si usa al posto di Caddy, per `location /v1/ai/` (o `/api/v1/ai/` con il prefisso):
  ```nginx
  proxy_buffering off;
  proxy_read_timeout 360s;
  proxy_http_version 1.1;
  ```
  Il backend invia comunque `X-Accel-Buffering: no` e un ping ogni 15 secondi.
- Traefik: nessuna configurazione particolare per lo streaming. Se è impostato `respondingTimeouts.readTimeout`, alzarlo sopra i 5 minuti.

**Modelli locali (Ollama, LM Studio).** Per sicurezza il server rifiuta i base URL "compatibili OpenAI" che puntano a indirizzi privati o locali, oppure in `http`. Questo impedisce che un utente usi il server per raggiungere servizi interni. Su un server personale, per usare un modello nella propria rete:

```env
AI_ALLOW_PRIVATE_BASE_URLS=true
```

In alternativa, `AI_ALLOWED_BASE_URL_HOSTS` accetta solo gli host indicati (per esempio `api.mistral.ai,openrouter.ai`).

Altri limiti configurabili sono descritti in `.env.example`: `AI_STREAM_MAX_DURATION`, `AI_STREAM_IDLE_TIMEOUT`, `AI_MAX_PROMPT_TOKENS` e `AI_RUNS_PER_HOUR`.

Riepilogo delle variabili dell'Analisi AI (tutte hanno un default in `compose.yaml`):

| Variabile | Default | Significato |
|---|---|---|
| `HTTP_REQUEST_TIMEOUT` | `30s` | Timeout di ogni richiesta, esclusi gli stream AI |
| `AI_KEY_ENCRYPTION_KEY` | vuota | Chiave AES-256 (32 byte in base64) per le chiavi API degli utenti; vuota = cloud disattivato |
| `AI_KEY_ENCRYPTION_KEY_PREVIOUS` | vuota | Chiave precedente, solo durante la rotazione |
| `AI_ALLOW_PRIVATE_BASE_URLS` | `false` | Ammette base URL privati/`http` per i servizi compatibili OpenAI |
| `AI_ALLOWED_BASE_URL_HOSTS` | vuota | Elenco di host ammessi, separati da virgola |
| `AI_STREAM_MAX_DURATION` | `5m` | Durata massima di uno stream cloud |
| `AI_STREAM_IDLE_TIMEOUT` | `90s` | Chiusura di uno stream cloud fermo |
| `AI_MAX_PROMPT_TOKENS` | `60000` | Dimensione massima stimata del prompt |
| `AI_RUNS_PER_HOUR` | `20` | Analisi cloud per utente all'ora |
| `AI_ON_DEVICE_ENABLED` | `true` | Analisi sul dispositivo |
| `AI_LOCAL_RUNS_PER_HOUR` | `30` | Report e domande sul dispositivo per utente all'ora |
| `AI_LOCAL_MAX_DURATION` | `30m` | Tempo concesso al telefono per finire un messaggio |

### 9. Analisi AI sul dispositivo

Con l'analisi sul dispositivo (plan.md sezione 33) il modello gira sul telefono dell'utente: il server costruisce il prompt dai dati e salva la cronologia, ma non chiama nessun fornitore. Non servono chiavi né traffico in uscita dal server, e funziona anche senza `AI_KEY_ENCRYPTION_KEY`: se il cloud non è configurato, l'app offre solo questa modalità.

- `AI_ON_DEVICE_ENABLED=false` la disattiva: l'app non mostra il selettore "Sul dispositivo" e le route `/v1/ai/local/…` rispondono `503 AI_ON_DEVICE_DISABLED`.
- `AI_LOCAL_RUNS_PER_HOUR` limita report e domande sul dispositivo per utente.
- `AI_LOCAL_MAX_DURATION` è la scadenza data al telefono per finire un messaggio; dopo, un messaggio ancora in attesa compare come interrotto.
- Le route locali sono JSON normali (niente streaming): il reverse proxy non ha bisogno di configurazioni particolari. L'invio del risultato accetta corpi fino a 512 KB.
- I modelli si scaricano dal telefono direttamente da Hugging Face: il server non li ospita e non li vede.

La migrazione `0034_ai_on_device` (applicata dal servizio `migrate` al riavvio) aggiunge a `ai_settings` la modalità, il modello locale e il consenso dedicato, a `ai_analyses` la colonna `runtime` e a `ai_messages` la durata. Il file `.down.sql` rimuove colonne e vincoli ma lascia le analisi `on_device` già salvate, che una versione precedente del backend non sa mostrare correttamente: prima di un rollback conviene eliminarle.

### 10. Spostare il backend su un'altra VPS

Procedura usata per passare da `remote-viewer` (vecchia VPS, condivisa con RemoteViewer) ad `alex-violatto`. Vale per qualsiasi spostamento: si copiano il database (dump PostgreSQL) e le immagini (volume di MinIO) e si tiene lo stesso `.env`. Redis non si copia: contiene solo cache, rate limit e chiavi di idempotenza. Il backend resta fermo per qualche minuto e, finché non si installa il nuovo APK, le app che puntano al vecchio indirizzo non funzionano.

Sulla vecchia VPS girano anche i container `rv-*` di RemoteViewer: tutti i comandi sotto usano solo il compose di FinancialManager (progetto `financial-manager`) e non li toccano.

**1. Preparare la nuova VPS** come nelle sezioni 1–3 (Docker, swap, clone, Caddy, DNS) e copiare il `.env` dalla vecchia, passando dal proprio PC:

```bash
scp remote-viewer:/projects/FinancialManager/financial-manager-backend/.env fm.env
scp fm.env alex-violatto:/projects/FinancialManager/financial-manager-backend/.env
rm fm.env
```

Sulla nuova cambiare solo `API_HOST_BIND=127.0.0.1` e aggiungere `TRUSTED_PROXY_CIDRS=172.16.0.0/12`. Tutti i segreti (`JWT_SIGNING_KEY`, `AI_KEY_ENCRYPTION_KEY`, `BACKUP_ENCRYPTION_KEY`, credenziali MinIO e `GDRIVE_*`) restano uguali: così le sessioni restano valide, le chiavi API degli utenti si decifrano e il worker continua a usare la stessa cartella di backup su Drive.

Costruire le immagini e avviare solo i servizi dati (vuoti):

```bash
cd /projects/FinancialManager/financial-manager-backend
docker compose -f compose.yaml -f compose.prod.yaml build
docker compose -f compose.yaml -f compose.prod.yaml up -d postgres redis object-storage
```

**2. Fermare la vecchia istanza ed esportare i dati** (da qui inizia il fermo):

```bash
cd /projects/FinancialManager/financial-manager-backend
C="docker compose -f compose.yaml -f compose.prod.yaml"
$C stop api worker
$C exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > ~/fm-migration.dump
$C exec -T postgres sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc   "select (select count(*) from users), (select count(*) from wallets), (select count(*) from transactions)"'
$C stop object-storage
docker run --rm -v financial-manager_object_storage_data:/data:ro -v ~:/backup alpine \
  tar czf /backup/fm-media.tar.gz -C /data .
ls -lh ~/fm-migration.dump ~/fm-media.tar.gz
```

Le variabili `$POSTGRES_USER` e `$POSTGRES_DB` sono tra apici singoli: le espande la shell del container, che le ha già nell'ambiente. Annotare i tre numeri stampati da `psql` (utenti, wallet, movimenti) per il controllo finale.

**3. Trasferire i file** passando dal proprio PC:

```bash
scp remote-viewer:fm-migration.dump remote-viewer:fm-media.tar.gz .
scp fm-migration.dump fm-media.tar.gz alex-violatto:
```

**4. Importare sulla nuova VPS:**

```bash
cd /projects/FinancialManager/financial-manager-backend
C="docker compose -f compose.yaml -f compose.prod.yaml"
$C exec -T postgres sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner' < ~/fm-migration.dump
$C stop object-storage
docker run --rm -v financial-manager_object_storage_data:/data -v ~:/backup alpine \
  sh -c 'rm -rf /data/* /data/.minio.sys && tar xzf /backup/fm-media.tar.gz -C /data'
$C up -d
```

`migrate` gira come sempre, ma trova lo schema già all'ultima versione e non fa nulla. Il volume di MinIO copiato dalla vecchia VPS (scritto da `minio/minio:RELEASE.2025-09-07`) viene aperto da `dokjolly/minio:RELEASE.2025-10-15…` senza conversioni (sezione 4, "Immagine di MinIO").

**5. Verificare** come nella sezione 5, poi:

- gli stessi conteggi di `users`, `wallets` e `transactions` letti al passo 2;
- dall'app (nuovo APK, vedi "Build Flutter"): accesso con Google e con password, un'immagine di una categoria o di un movimento, un'analisi AI;
- nei log dell'API l'IP del client e non un `172.x`.

**6. Spegnere la vecchia istanza**, senza cancellare i volumi:

```bash
# su remote-viewer
cd /projects/FinancialManager/financial-manager-backend
docker compose -f compose.yaml -f compose.prod.yaml down   # niente -v
```

I volumi `financial-manager_postgres_data` e `financial-manager_object_storage_data` e i file `~/fm-migration.dump` e `~/fm-media.tar.gz` restano sulla vecchia VPS come copia di sicurezza per qualche settimana. Mai tenere accese le due istanze insieme: due worker farebbero due backup diversi nella stessa cartella di Drive.

**Rollback** (se la nuova istanza non funziona): sulla nuova `docker compose ... stop api worker`, sulla vecchia `docker compose -f compose.yaml -f compose.prod.yaml up -d` e installare un APK compilato con `--dart-define=API_BASE_URL=http://83.228.246.84:10003/v1` in debug (le release non accettano `http`). Le modifiche fatte nel frattempo sulla nuova istanza vanno perse, a meno di rifare il passo 2 al contrario.

**Pulizia, a migrazione confermata:**

```bash
# su remote-viewer
docker volume rm financial-manager_postgres_data financial-manager_object_storage_data
rm ~/fm-migration.dump ~/fm-media.tar.gz
# su alex-violatto
rm ~/fm-migration.dump ~/fm-media.tar.gz
```

## Build Flutter

L'app Flutter legge l'URL API da `--dart-define`.

File rilevante:

```text
financial-manager-app/lib/core/api/api_environment.dart
```

Default attuale:

- `local`: `http://10.0.2.2:10003/v1` (backend locale visto dall'emulatore Android)
- `production`: `https://financialmanager.alexviolatto.dev/api/v1`

`API_ENVIRONMENT` vale `production` se non indicato, quindi una build senza `--dart-define` punta già al server di produzione. `--dart-define=API_BASE_URL=...` sostituisce l'URL in ogni caso (test, emergenze, un altro server).

**Traffico in chiaro.** Le build release accettano solo HTTPS: `android/app/src/main/AndroidManifest.xml` non permette `http`. Solo le build debug lo permettono (`android:usesCleartextTraffic="true"` in `android/app/src/debug/AndroidManifest.xml`), per parlare con il backend locale sull'emulatore.

### 1. Preparare dipendenze

```bash
cd financial-manager-app
flutter pub get
```

### 2. Test

```bash
flutter test
```

### 3. Firma Android

L'app si firma con **una sola chiave** (keystore), uguale su ogni PC: le build release e anche le debug. Così:

- Google Sign-In ha bisogno di un solo SHA-1 registrato su Google Cloud, qualunque PC abbia compilato l'APK, anche con `flutter run`;
- un APK compilato su un PC aggiorna l'app installata da un APK compilato su un altro;
- la stessa chiave farà da *upload key* per il Play Store.

Come funziona: `android/app/build.gradle.kts` legge `android/key.properties`. Se il file c'è, firma release e debug con la chiave indicata; se non c'è, usa la chiave debug locale del PC (come fa la CI), così chi non ha la chiave può comunque compilare, ma l'APK ottenuto ha un altro certificato: non aggiorna l'app installata e il login con Google non funziona.

`key.properties`, `*.jks` e `*.keystore` sono in `android/.gitignore`: **non vanno mai committati**.

**Creare la chiave (una volta sola).** `keytool` è incluso nel JDK di Android Studio (`<Android Studio>/jbr/bin/keytool`):

```powershell
mkdir $HOME\.android-keys
keytool -genkeypair -v -storetype PKCS12 `
  -keystore $HOME\.android-keys\financialmanager-upload.jks `
  -alias upload -keyalg RSA -keysize 4096 -validity 10000
```

`keytool` chiede una password (con PKCS12 vale sia per il keystore sia per la chiave) e nome e organizzazione per il certificato, che non vengono mostrati agli utenti. `-validity 10000` sono circa 27 anni: il Play Store richiede una scadenza oltre il 2033.

**Configurare un PC.** Copiare `android/key.properties.example` in `android/key.properties` e compilarlo:

```properties
storeFile=C:/Users/Alex/.android-keys/financialmanager-upload.jks
storePassword=LA_PASSWORD
keyAlias=upload
keyPassword=LA_PASSWORD
```

`storeFile` può essere un percorso assoluto (con `/` anche su Windows); un percorso relativo parte da `android/app`.

**Usarla su più PC.** Salvare il file `.jks` e la password in un password manager (per esempio come allegato in Bitwarden o 1Password), non nel repository né in una cartella condivisa in chiaro. Su un nuovo PC: copiare il `.jks` nella stessa posizione (o in un'altra, aggiornando `storeFile`) e creare `key.properties` come sopra. Nient'altro: lo SHA-1 resta lo stesso.

**Se la chiave va persa** non si possono più pubblicare aggiornamenti che si installino sopra l'app esistente: gli utenti dovrebbero disinstallarla e reinstallarla. Sul Play Store, con Play App Signing (sotto), si può chiedere il reset della sola *upload key* dalla Play Console. Per questo la copia nel password manager è indispensabile.

**Impronte del certificato** (SHA-1 e SHA-256):

```bash
keytool -list -v -keystore ~/.android-keys/financialmanager-upload.jks -alias upload
```

oppure, dalla cartella `android`, `./gradlew signingReport` (riporta i certificati delle varianti debug e release). Per controllare con quale chiave è firmato un APK:

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

(`apksigner` è in `<Android SDK>/build-tools/<versione>/`.)

**Google Cloud Console (Google Sign-In).** In *API e servizi → Credenziali* del progetto che contiene il client web `394336083524-bulv…`:

1. *Crea credenziali → ID client OAuth → Android*;
2. nome del pacchetto `com.alexviolatto.financialmanager`, impronta SHA-1 della chiave;
3. salvare. Non serve copiare l'ID del client Android da nessuna parte: Google lo riconosce da pacchetto e certificato.

Il client **web** (`serverClientId` nell'app e `GOOGLE_CLIENT_IDS` nel backend) non cambia. I vecchi client Android con gli SHA-1 debug dei singoli PC si possono eliminare dopo aver verificato il login con la nuova chiave. Se dopo il cambio il login fallisce con `DEVELOPER_ERROR` / codice 10, lo SHA-1 o il nome del pacchetto non corrispondono (le modifiche su Google Cloud possono richiedere qualche minuto).

**Cambio di firma sui telefoni.** Android non installa un APK firmato con un'altra chiave sopra l'app esistente (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). La prima volta che si passa alla nuova chiave bisogna disinstallare l'app: i dati sono sul server e tornano con l'accesso, ma i modelli AI scaricati sul telefono vanno riscaricati.

### 4. Build APK release

```bash
flutter build apk --release --target-platform android-arm64
```

L'URL di produzione è il default; per un altro server:

```bash
flutter build apk --release --target-platform android-arm64 \
  --dart-define=API_BASE_URL=https://altro.dominio/api/v1
```

Output tipico:

```text
financial-manager-app/build/app/outputs/flutter-apk/app-release.apk
```

Con `android/key.properties` presente l'APK è firmato con la chiave di release (sezione 3); senza, con la chiave debug del PC.

**Motori AI sul dispositivo.** L'app include LiteRT-LM e llama.cpp (plan.md sezione 33.11), che occupano la maggior parte del codice nativo:

- la release contiene solo `arm64-v8a` (le altre ABI sono escluse in `android/app/build.gradle.kts`): l'APK pesa circa 92 MB. Per vedere il dettaglio della dimensione:
  ```bash
  flutter build apk --release --target-platform android-arm64 --analyze-size
  ```
  `--analyze-size` scrive il dettaglio della dimensione in `build/`; la CI lo esegue a ogni build;
- `minSdk` è 30 (Android 11): i telefoni più vecchi non possono installare l'app;
- llama.cpp viene compilato solo con il backend CPU (`hooks.user_defines.llamadart` in `pubspec.yaml`): il backend Vulkan andava in crash sulle GPU Adreno e da solo aggiungeva 26 MB;
- le build debug includono tutte le ABI e pesano circa 300 MB;
- la prima build dopo `flutter clean` è lenta (5–15 minuti) perché gli hook compilano le librerie native.

**Lavoro in background.** Download dei modelli e analisi sul dispositivo continuano con l'app chiusa grazie a un servizio in primo piano (`flutter_foreground_task`):

- il manifest dichiara i permessi `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS` e `WAKE_LOCK`, e il servizio con i tipi `dataSync|specialUse`. Per una pubblicazione su Play Store il tipo `specialUse` va motivato nella console (la motivazione è già nella `property` del manifest);
- il motore Flutter parte in `FinancialManagerApplication` e resta in cache, così il lavoro sopravvive alla chiusura dell'app dalle recenti;
- `flutter_local_notifications` richiede il desugaring delle librerie Java (`isCoreLibraryDesugaringEnabled` e `desugar_jdk_libs` in `android/app/build.gradle.kts`);
- da Android 15 i servizi `dataSync` hanno un tetto di 6 ore al giorno: oltre, i download vanno in pausa e riprendono riaprendo l'app.

Controllo rapido che Vulkan non sia finito nell'APK:

```bash
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -i vulkan   # nessun risultato
```

### 5. Build Android App Bundle e Play Store

Per Play Store si carica un `.aab`:

```bash
flutter build appbundle --release
```

Output tipico:

```text
financial-manager-app/build/app/outputs/bundle/release/app-release.aab
```

**Play App Signing.** Sul Play Store l'app pubblicata è firmata da Google con una sua chiave; la nostra keystore diventa la *upload key*, con cui si firmano solo i bundle caricati. Alla prima pubblicazione:

1. creare l'app nella Play Console con il pacchetto `com.alexviolatto.financialmanager` e accettare Play App Signing (lasciare che Google generi la chiave di firma dell'app);
2. caricare il primo `.aab` firmato con la nostra chiave: diventa automaticamente la upload key registrata;
3. in *Configurazione → Integrità dell'app → Firma dell'app* copiare lo **SHA-1 della chiave di firma dell'app** (quella di Google) e aggiungerlo su Google Cloud come un secondo client OAuth Android (stesso pacchetto). Senza, il login con Google non funziona nelle installazioni dal Play Store, mentre continua a funzionare negli APK installati a mano.

Un APK installato a mano (firmato con la nostra chiave) e uno dal Play Store (firmato da Google) hanno certificati diversi: per passare dall'uno all'altro sul telefono bisogna disinstallare.

**Versioni.** `versionCode` e `versionName` vengono da `version:` in `pubspec.yaml` (`1.2.0+5` → `versionName` 1.2.0, `versionCode` 5). Ogni bundle caricato deve avere un `versionCode` più alto del precedente.

### 6. Build iOS

iOS richiede macOS con Xcode. Non si compila su una VPS Linux standard.

Il target minimo è iOS 15 (richiesto da `flutter_edge_ai`). L'analisi sul dispositivo su iOS non è ancora disponibile: l'app la mostra come non supportata.

Su macOS:

```bash
cd financial-manager-app
flutter pub get
flutter build ipa --release
```

### 7. Firma in CI (implementazione futura)

Oggi la CI (`.github/workflows/mobile-ci.yml`) compila la release senza `key.properties`, quindi firmata con una chiave debug usa e getta: serve solo a controllare che la build passi. Per ottenere dalla CI APK e bundle firmati con la chiave vera:

1. nei *Secrets* del repository GitHub aggiungere:
   - `ANDROID_KEYSTORE_BASE64`: il `.jks` in base64 (`base64 -w0 financialmanager-upload.jks`, su Windows `[Convert]::ToBase64String([IO.File]::ReadAllBytes("financialmanager-upload.jks"))`);
   - `ANDROID_KEYSTORE_PASSWORD`;
   - `ANDROID_KEY_ALIAS` (`upload`);
2. in `mobile-ci.yml`, nel job `build-android` e solo per i push su `main` (le pull request da fork non vedono i secrets), prima della build:
   ```yaml
   - name: Restore upload key
     if: github.event_name == 'push' && github.ref == 'refs/heads/main'
     working-directory: financial-manager-app/android
     env:
       KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
       KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
       KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
     run: |
       echo "$KEYSTORE_BASE64" | base64 -d > "$RUNNER_TEMP/upload.jks"
       {
         echo "storeFile=$RUNNER_TEMP/upload.jks"
         echo "storePassword=$KEYSTORE_PASSWORD"
         echo "keyAlias=$KEY_ALIAS"
         echo "keyPassword=$KEYSTORE_PASSWORD"
       } > key.properties
   ```
3. dopo la build, pubblicare `app-release.apk` e `app-release.aab` con `actions/upload-artifact`, ed eventualmente caricare il bundle sul Play Store (traccia interna) con un'azione dedicata e un service account della Play Console.

Il runner viene distrutto a fine job, quindi `upload.jks` e `key.properties` non restano da nessuna parte; non stamparli mai nei log.

## Cose da sistemare prima di una release pubblica

Già fatto:

- firma release Android con una keystore unica (sezione "Firma Android");
- API in HTTPS dietro Caddy, porta `10003` solo su loopback;
- `android:usesCleartextTraffic` tolto dalle build release.

Ancora da fare prima di distribuire a utenti reali:

- Registrare su Google Cloud lo SHA-1 della chiave di firma di Play (alla prima pubblicazione) e il bundle ID iOS se usi Google Sign-In su iOS.
- Dashboard web: build Flutter web e pubblicazione in `/var/www/financialmanager` (piano separato).
- Firma in CI (sezione 7 di "Build Flutter").
- Storage delle immagini: MinIO community non è più mantenuto. Oggi si usa la sua ultima release ricompilata (`dokjolly/minio`, sezione 4); nel lungo periodo valutare uno storage compatibile S3 ancora sviluppato (per esempio Garage o SeaweedFS). Il backend usa un client S3 standard, quindi cambierebbero solo il compose, la copia del bucket e gli script di backup.
- Non committare mai `.env`, keystore, `key.properties`, password o chiavi.

File da controllare:

```text
financial-manager-app/android/app/build.gradle.kts
financial-manager-app/android/app/src/main/AndroidManifest.xml
financial-manager-app/android/app/src/debug/AndroidManifest.xml
financial-manager-backend/deploy/Caddyfile.example
```

## Checklist veloce

Backend (sulla VPS `alex-violatto`):

```bash
cd /projects/FinancialManager
git pull
cd financial-manager-backend
docker compose -f compose.yaml -f compose.prod.yaml up -d --build
curl https://financialmanager.alexviolatto.dev/api/health/ready
```

Flutter APK (con `android/key.properties` configurato):

```bash
cd financial-manager-app
flutter pub get
flutter test
flutter build apk --release --target-platform android-arm64
```

Flutter App Bundle:

```bash
cd financial-manager-app
flutter pub get
flutter test
flutter build appbundle --release
```
