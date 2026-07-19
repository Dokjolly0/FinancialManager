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
```

Generare `JWT_SIGNING_KEY` con:

```bash
openssl rand -base64 48
```

In produzione `JWT_SIGNING_KEY`, `OBJECT_STORAGE_ACCESS_KEY` e `OBJECT_STORAGE_SECRET_KEY` sono obbligatori.

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

In produzione i backup devono andare su storage esterno alla VPS o almeno fuori dai volumi Docker. Redis non viene incluso perche' contiene cache/rate limit/idempotency temporanea, non dati finanziari sorgente.

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

- Cambiare `applicationId` Android da `com.example.financialmanager` a un package reale.
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
