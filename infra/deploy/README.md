# Deployment notes

Nothing in this repository is a public deployment. No URL was left serving on the internet, and no DNS or TLS name was configured. The public HTTPS gate is blocked.

For the current candidate, see [M9 release validation](../../docs/milestones/M9_RELEASE_CANDIDATE.md). The evidence below is historical and is superseded where the candidate report records a newer check.

## Historical 0.20.0 pass

- `./scripts/export_web.sh` printed `WEB_EXPORT_OK`, `WEB_FINISH_OK`, and `WEB_VERIFY_OK`. Godot was `4.7.2.stable.official.ed1daf0bf`. `build/web/` is gitignored. `index.html` loads `md-config.js` and sets `GODOT_THREADS_ENABLED` to false. `md-config.js` does not contain a loopback address or a session token. The pck contains `export_shared` and the client version `0.20.0`.
- `./scripts/smoke_web.sh` printed `WEB_SMOKE_OK http://127.0.0.1:8097/index.html`. Wasm was `application/wasm`. The smoke process exited. A separate local server was left on that port afterward.
- `.venv/bin/python scripts/browser_smoke.py --port 8098 --debug-port 9333` printed `BROWSER_SMOKE_OK` for `/opt/google/chrome/chrome`. The page had a canvas and Godot's `Engine` object. It was loopback HTTP. It was not a match, not Firefox, not Safari, and not a phone.
- `pytest` included the production env example, the deadline sweep, invite lookup, and a two-session match to `game_ended`. The live API on `127.0.0.1:8741` answered `/health` with `"environment":"local"` and an invite lookup that omitted the session token.
- The container image was not rebuilt. `infra/Dockerfile` now sets `MD_ENV=container`. An older image probe is still described in [RUNBOOK.md](../../RUNBOOK.md) and was not repeated.

## Files to copy onto a host

| Path | Use |
| --- | --- |
| `infra/deploy/cloudflare/_headers` | Static host cache and WASM content type. The export copies this into `build/web/_headers`. |
| `infra/deploy/caddy/Caddyfile` | HTTPS in front of one long-lived API process. Replace `api.example.com`. |
| `infra/deploy/production.env.example` | Variable names for `MD_ENV=production`. Copy it on the host. Do not commit the copy. |

SQLite stays the beta database. `postgres://` and `postgresql://` abort startup and name `infra/migrations/0001_rooms.sql`. Do not point this process at PostgreSQL.

Secrets stay in the host environment. The compose password `market` is a local default. Change it before port 5432 is reachable beyond one machine.

One API process owns the in-memory room lock, the WebSocket hub, and the deadline loop. A second worker would sweep and apply without shared coordination. Do not scale out until that moves out of the process.

## M9 release candidate deployment procedure

1. Run one persistent API process (one worker) on a host with durable SQLite storage. Back up the database before deployment. The WebSocket hub, room lock and deadline loop are process-local; multiple workers are unsupported.
2. Build `infra/Dockerfile`; its runtime normalizes shared asset permissions and its healthcheck probes `/ready`. In a managed proxy environment, supply the public trust bundle with `docker build --secret id=proxy_ca,src=/etc/ssl/certs/ca-certificates.crt -f infra/Dockerfile -t market-dominion:m9-rc .`. The optional mount configures pip trust without disabling TLS verification or retaining a session CA in the image.
3. Set the process environment using `production.env.example`: `MD_ENV=production`, real `https://` API and `wss://` socket URLs, exact `MD_CORS_ORIGINS`, and a persistent SQLite location. The app does not load `.env` automatically. Keep credentials and database backups out of the static export.
4. Configure real DNS names and TLS at the static host and API reverse proxy. Adapt the Caddy example, keep WebSocket upgrades supported, and keep the API off short-lived serverless functions.
5. Export the client, upload every file in `build/web/`, and preserve `_headers` MIME/cache rules. Set `window.MD_SERVER` in `md-config.js` to the real HTTPS API origin, or use the explicit server query parameter. Do not put session tokens in either. This single-threaded export does not require COOP/COEP.
6. Probe `/health` and `/ready` through public HTTPS. Test the actual game page in two independent browsers: first invitation join, ready/start, private hands, trades, events, refresh, reconnect and identical final standings. Record the public URL and browser versions before marking public deployment verified. Follow [M9 browser acceptance](../../docs/milestones/M9_BROWSER_ACCEPTANCE.md).

Public hosting remains blocked until an authorized host, DNS/TLS access and a real public URL are available. Local HTTP, a container healthcheck, and a successful canvas smoke do not satisfy that gate.
