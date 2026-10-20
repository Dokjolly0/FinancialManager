# Build e deploy

Guida operativa per pubblicare il backend su una VPS e compilare l'app Flutter.

## Backend su VPS

Il backend e' un'app Go eseguita via Docker Compose con PostgreSQL, Redis e MinIO. I file principali sono:

- `financial-manager-backend/compose.yaml`
- `financial-manager-backend/compose.prod.yaml`
- `financial-manager-backend/.env.example`
- `financial-manager-backend/Dockerfile`

### 1. Preparare la VPS

Sulla VPS devono essere installati:

- Docker
- Docker Compose plugin
- Git
- OpenSSL, utile per generare segreti

Poi clonare o copiare il repository sulla macchina.

### 2. Creare il file `.env`

Entrare nella cartella backend:

```bash
cd financial-manager-backend
cp .env.example .env
```

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

API_HOST_BIND=0.0.0.0
API_HOST_PORT=10003

BACKUP_ENCRYPTION_KEY=CAMBIA_CON_CHIAVE_RANDOM_LUNGA
GDRIVE_CLIENT_ID=xxxxxxxx.apps.googleusercontent.com
GDRIVE_CLIENT_SECRET=CAMBIA
GDRIVE_REFRESH_TOKEN=CAMBIA

# Facoltativo: abilita l'Analisi AI (vedi sezione 8)
AI_KEY_ENCRYPTION_KEY=CAMBIA_CON_OPENSSL_RAND_BASE64_32
```

Generare `JWT_SIGNING_KEY` e `BACKUP_ENCRYPTION_KEY` (due valori diversi) con:

```bash
openssl rand -base64 48
```

In produzione `JWT_SIGNING_KEY`, `OBJECT_STORAGE_ACCESS_KEY` e `OBJECT_STORAGE_SECRET_KEY` sono obbligatori.

In produzione il backup automatico su Google Drive e' attivo di default: senza `BACKUP_ENCRYPTION_KEY` e le tre variabili `GDRIVE_*` il backup non viene eseguito e il `worker` registra `backup_not_configured` nei log a ogni controllo orario, mentre gli altri job continuano a funzionare normalmente. Come ottenerle e' spiegato in `financial-manager-backend/docs/backup-restore.md` (sezione "Off-site backups to Google Drive"). Per disattivarlo esplicitamente: `BACKUP_ENABLED=false`. Conservare una copia di `BACKUP_ENCRYPTION_KEY` fuori dalla VPS (es. password manager): senza, i backup su Drive non si possono decifrare.

### 3. Avviare lo stack production

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

Il servizio `migrate` applica le migrazioni SQL prima dell'avvio dell'API e del worker.

### 4. Verificare il deploy

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

Verificare l'health check:

```bash
curl http://IP_DELLA_VPS:10003/health/ready
```

L'API espone le route applicative sotto `/v1`, quindi l'app Flutter deve puntare a:

```text
http://IP_DELLA_VPS:10003/v1
```

### 5. Firewall e HTTPS

Soluzione rapida:

- aprire la porta `10003` sul firewall della VPS;
- usare nell'app `http://IP_DELLA_VPS:10003/v1`.

Soluzione consigliata:

- configurare un dominio, per esempio `api.tuodominio.it`;
- usare Caddy, Nginx o Traefik come reverse proxy HTTPS;
- far puntare il proxy al backend sulla porta interna `10003`.

Con reverse proxy locale, impostare:

```env
API_HOST_BIND=127.0.0.1
API_HOST_PORT=10003
```

L'app dovra' puntare a:

```text
https://api.tuodominio.it/v1
```

### 6. Aggiornare il backend dopo modifiche

Sulla VPS:

```bash
git pull
cd financial-manager-backend
docker compose -f compose.yaml -f compose.prod.yaml up -d --build
```

Se vuoi forzare il rebuild senza cache:

```bash
docker compose -f compose.yaml -f compose.prod.yaml build --no-cache
docker compose -f compose.yaml -f compose.prod.yaml up -d
```

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

- Caddy: `reverse_proxy 127.0.0.1:10003 { flush_interval -1 }`. Caddy non ha un timeout di lettura di default.
- Nginx, per `location /v1/ai/`:
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

## Build Flutter

L'app Flutter legge l'URL API da `--dart-define`.

File rilevante:

```text
financial-manager-app/lib/core/api/api_environment.dart
```

Default attuale:

- `local`: `http://10.0.2.2:10003/v1`
- `production`: `http://83.228.246.84:10003/v1`

Anche se c'e' un default production, e' meglio passare sempre `API_BASE_URL` in fase di build.

### 1. Preparare dipendenze

```bash
cd financial-manager-app
flutter pub get
```

### 2. Test

```bash
flutter test
```

### 3. Build APK release

Con IP diretto:

```bash
flutter build apk --release \
  --dart-define=API_ENVIRONMENT=production \
  --dart-define=API_BASE_URL=http://IP_DELLA_VPS:10003/v1
```

Con dominio HTTPS:

```bash
flutter build apk --release \
  --dart-define=API_ENVIRONMENT=production \
  --dart-define=API_BASE_URL=https://api.tuodominio.it/v1
```

Output tipico:

```text
financial-manager-app/build/app/outputs/flutter-apk/app-release.apk
```

### 4. Build Android App Bundle

Per Play Store usare preferibilmente `.aab`:

```bash
flutter build appbundle --release \
  --dart-define=API_ENVIRONMENT=production \
  --dart-define=API_BASE_URL=https://api.tuodominio.it/v1
```

Output tipico:

```text
financial-manager-app/build/app/outputs/bundle/release/app-release.aab
```

### 5. Build iOS

iOS richiede macOS con Xcode. Non si compila su una VPS Linux standard.

Su macOS:

```bash
cd financial-manager-app
flutter pub get
flutter build ipa --release \
  --dart-define=API_ENVIRONMENT=production \
  --dart-define=API_BASE_URL=https://api.tuodominio.it/v1
```

## Cose da sistemare prima di una release pubblica

Prima di pubblicare su store o distribuire a utenti reali:

- Configurare una firma release Android con keystore, non la firma debug.
- Registrare package Android, SHA-1/SHA-256 e bundle ID iOS in Google Cloud Console se usi Google Sign-In.
- Usare HTTPS in produzione.
- Dopo il passaggio a HTTPS, rimuovere `android:usesCleartextTraffic="true"` dal manifest Android.
- Non committare mai `.env`, keystore, password o chiavi.

File Android da controllare:

```text
financial-manager-app/android/app/build.gradle.kts
financial-manager-app/android/app/src/main/AndroidManifest.xml
```

## Checklist veloce

Backend:

```bash
cd financial-manager-backend
cp .env.example .env
# modificare .env
docker compose -f compose.yaml -f compose.prod.yaml up -d --build
curl http://IP_DELLA_VPS:10003/health/ready
```

Flutter APK:

```bash
cd financial-manager-app
flutter pub get
flutter test
flutter build apk --release --dart-define=API_ENVIRONMENT=production --dart-define=API_BASE_URL=http://IP_DELLA_VPS:10003/v1
```

Flutter App Bundle:

```bash
cd financial-manager-app
flutter pub get
flutter test
flutter build appbundle --release --dart-define=API_ENVIRONMENT=production --dart-define=API_BASE_URL=https://api.tuodominio.it/v1
```
