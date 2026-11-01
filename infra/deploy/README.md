# Deployment notes

Nothing in this repository is a public deployment. No URL was left serving on the internet, and no DNS or TLS name was configured. The public HTTPS gate is blocked.

## Verified in the 0.20.0 pass

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
