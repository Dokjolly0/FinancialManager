# Backup e ripristino

Implementa plan.md sezione 20.4/21.10. Copre PostgreSQL (la fonte di verità
per saldi e transazioni) e il bucket dell'object storage (le immagini).
Redis non è incluso di proposito: contiene solo cache, rate limit e record
di idempotenza, mai l'unica copia di un dato (plan.md sezione 20.4/12.4).

## Script

- `scripts/backup.sh` — esegue `pg_dump` (formato custom) e specchia il
  bucket con un container `minio/mc` usa e getta (nessuna installazione
  richiesta sull'host oltre a Docker e `openssl`). Se `BACKUP_ENCRYPTION_KEY`
  è impostata, entrambi i backup vengono cifrati (`openssl enc -aes-256-cbc`).
  Applica la retention (`RETENTION_DAYS`, default 30) cancellando i backup
  più vecchi.
- `scripts/restore.sh <dump-file> [target-db] [compose-files...]` — ripristina
  in un database di destinazione, di default `<db>_restore_test` per non
  poter mai sovrascrivere per errore quello reale (serve
  `CONFIRM_OVERWRITE=yes` esplicito per farlo).
- `scripts/test-restore.sh` — prende l'ultimo backup, lo ripristina in un
  database usa e getta, confronta il conteggio righe di `users`/`wallets`/
  `transactions` con la sorgente live, poi elimina il database di prova.
  Implementa il "test periodico di restore" richiesto dal piano: un backup
  mai ripristinato non è un backup.

Tutti gli script vanno eseguiti dalla cartella `financial-manager-backend`
con lo stack Docker già attivo (`docker compose -f compose.yaml -f
compose.dev.yaml up -d`, o l'equivalente di staging/produzione).

## Retention e cifratura

- **Locale/sviluppo**: retention breve (es. 7 giorni) è sufficiente;
  `BACKUP_ENCRYPTION_KEY` è opzionale.
- **Staging/produzione**: `BACKUP_ENCRYPTION_KEY` deve provenire dal secret
  manager dell'ambiente, mai da `.env` (plan.md sezione 19.4). Retention
  consigliata da confermare con il proprietario del prodotto in base a
  requisiti legali/di prodotto — 30 giorni giornalieri + 12 mensili è un
  punto di partenza ragionevole, non una policy definitiva.
- I backup vanno scritti su uno storage distinto da quello di produzione
  (mai lo stesso volume Docker) — questi script scrivono in locale
  (`BACKUP_DIR`, default `./backups`) per semplicità; in produzione
  `BACKUP_DIR` deve puntare a uno storage esterno con accesso ristretto.

## Programmazione

Va eseguito da un cron/scheduler esterno al container applicativo, ad
esempio:

```cron
0 3 * * * cd /path/to/financial-manager-backend && BACKUP_ENCRYPTION_KEY=$(cat /run/secrets/backup_key) ./scripts/backup.sh compose.yaml compose.prod.yaml >> /var/log/fm-backup.log 2>&1
0 5 * * 0 cd /path/to/financial-manager-backend && BACKUP_ENCRYPTION_KEY=$(cat /run/secrets/backup_key) ./scripts/test-restore.sh compose.yaml compose.prod.yaml >> /var/log/fm-restore-test.log 2>&1
```

Un fallimento di `test-restore.sh` è un evento da allarme (plan.md sezione
22.3: "Backup fallito").
