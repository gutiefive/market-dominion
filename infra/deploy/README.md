# Deployment notes

Nothing in this repository is a public deployment. No URL was left serving, and no DNS or TLS name was configured.

## Verified here

- `./scripts/export_web.sh` wrote `build/web/` and printed `WEB_EXPORT_OK`. The files are gitignored. `index.html` is a single-threaded Compatibility export (`GODOT_THREADS_ENABLED = false`).
- `./scripts/smoke_web.sh` printed `WEB_SMOKE_OK http://127.0.0.1:8097/index.html`. That process exited. It was not a browser and it was not HTTPS.
- `docker build -f infra/Dockerfile -t market-dominion-api:local .` produced image `0e9f554b751a`. A container on `127.0.0.1:8751` answered `/health` and `/ready`, created a room, ran as uid 10001, and stored `/data/market.db` as that user. The container was removed.
- `DATABASE_URL=postgresql://...` made that image exit before it listened. The error names `infra/migrations/0001_rooms.sql`.
- `psql` is not installed, so the migration script was not applied. `docker compose` is not installed, so `docker-compose.yml` was not started and the Postgres image was not pulled.

## Intended shape, not yet run

- Static files from `build/web/` on a static host. Set the MIME and cache headers in [RUNBOOK.md](../../RUNBOOK.md). This export does not need COOP or COEP.
- The FastAPI process on a host that keeps WebSocket connections open. Do not put it on a short-lived serverless function. Terminate TLS in front of it.
- SQLite on a persistent disk (`MD_DATABASE_PATH` or `sqlite:///` ). PostgreSQL DDL is prepared and unused. Do not point the API at it.
- `MD_CORS_ORIGINS` set to the exact origin of the static page. The page is opened as `index.html?server=https://<api-host>`, which selects `wss`.

Secrets stay in the host environment. `.env.example` is the list of names. The compose password `market` is a local default. Change it before port 5432 is reachable beyond one machine.
