# Runbook

## Local API

```bash
./scripts/dev.sh
```

- Binds `127.0.0.1:8741` unless `MD_PORT` is set.
- Installs `websockets`, which Uvicorn needs before it will upgrade `/v1/rooms/ws`.
- Creates `.venv` and installs the package editable.
- SQLite path: `server/data/market.db`, or `MD_DATABASE_PATH`.
- Stop with Ctrl-C. The schema_version 1 file can be deleted; the next `/ready` recreates it. Deleting it drops every persisted room.

Checks:

```bash
curl -sS http://127.0.0.1:8741/health
curl -sS http://127.0.0.1:8741/ready
```

`/ready` returns `database_schema_version` `1` and `currency` `fictional`.

Validate a sample command without applying it:

```bash
curl -sS -X POST http://127.0.0.1:8741/v1/protocol/commands/validate \
  -H 'content-type: application/json' \
  --data-binary @shared/fixtures/commands/place_tile.json
```

Expect `"applied": false`.

## Client

```bash
./scripts/check_client.sh
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path client
```

The check imports the project headless and must print `M0_CLIENT_OK` through `M6_CLIENT_OK`. The window is the local table. Deal with a seed, pass the device, place one tile, found or grow a company, resolve a merger, then confirm up to two market actions. Keys: 1–5 select a tile, Enter places it, R opens the rules, Esc closes a panel, `[` and `]` change text size, M toggles reduced motion. Under about 980 px the watchlist stacks under the grid. Online room uses the server URL field (default `http://127.0.0.1:8741`). One window creates a room. A second window joins with the match id and invite code, both press Ready, and the host presses Start. Start stays disabled until 2–4 players are ready. Each window shows its own tiles. Desktop captures: `docs/m6-table.png`, `docs/m6-rules.png`, `docs/m6-lobby.png`, `docs/m6-online.png`. `docs/m6-narrow.png` is a 420×800 window, not a device.

Set `GODOT_BIN` to skip the download. The script still refuses a binary whose `--version` output is not `4.7.2.stable.official.ed1daf0bf`, because `client/tests/m0_check.gd` asserts that string.

Screenshot (needs a display; not part of CI). `opening` shows the dealt hand. `placed` plays the first tile and covers the next hand.

```bash
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path client --display-driver x11 \
  --audio-driver Dummy --resolution 1280x720 \
  -- --shot docs/m1-opening.png opening
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path client --display-driver x11 \
  --audio-driver Dummy --resolution 1280x720 \
  -- --shot docs/m1-placed.png placed
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path client --display-driver x11 \
  --audio-driver Dummy --resolution 420x800 \
  -- --shot docs/m1-narrow.png opening
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path client --display-driver x11 \
  --audio-driver Dummy --resolution 1280x720 \
  -- --shot docs/m2-economy.png economy
```

Online evidence needs the API already running and a room the token can read. Arguments after `online` are match id, session token, invite code, and port:

```bash
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path client --display-driver x11 \
  --audio-driver Dummy --resolution 1280x720 \
  -- --shot docs/m5-room.png online MATCH TOKEN INVITE 8741
```

## Two clients

Start `./scripts/dev.sh`. Open two Godot windows with `--path client`. In the first, Online room, Create private room. Copy the match id and invite into the second window and Join. Ready on both. Start on the host window. A command from the waiting seat returns `out_of_turn`. Repeating the same `client_action_id` does not apply twice.

## Tests and CI

```bash
./scripts/test.sh
```

GitHub Actions workflow `.github/workflows/ci.yml` runs pytest on Python 3.12 and `scripts/check_client.sh` on the 4.7.2 Linux binary.

## Logs and data

The `market` logger writes one JSON object per line to stderr. `MD_LOG_LEVEL` defaults to `info`. Fields named password, secret, token, session_token, database_url, or authorization are dropped. Startup logs the protocol version, `database_backend=sqlite`, and the CORS origin count. It does not log the database URL. An unhandled exception logs `unhandled` with the path and the exception type, and the HTTP body is `{"detail":"server_error"}`. Uvicorn's own access lines stay plain text. There is no remote alert sink. Ship stderr to whatever collector you run.

Tables are `schema_meta` and `rooms`. The file is `server/data/market.db`, or `MD_DATABASE_PATH`, or the path inside a `sqlite:///` `DATABASE_URL`. `DATABASE_URL` wins when both are set. Deleting that file drops rooms and is the local rollback. A version `0` file upgrades to `1` on the next open. Copy the file to back it up. Stop the API first so SQLite is not mid-write. Restore by putting the copy back at the same path and starting the API again.

## What was run in this environment

- `./scripts/export_web.sh` wrote `build/web/` (gitignored). The template archive SHA-512 matched the pin in that script. `GODOT_TEMPLATES_TPZ` pointed at the already downloaded file, so the script checked the hash and unzipped it instead of fetching it a second time.
- `./scripts/smoke_web.sh` printed `WEB_SMOKE_OK http://127.0.0.1:8097/index.html`. Loopback HTTP. The process then exited. No browser, no HTTPS.
- `docker build -f infra/Dockerfile -t market-dominion-api:local .` produced image `0e9f554b751a`. `docker run -p 8751:8741` answered `/health`, `/ready` (schema `1`, backend `sqlite`), and a create-room POST 200. The server process was uid 10001. `/data/market.db` was owned by 10001. Logs started with a JSON `api_start` line. The container was removed. Nothing is still listening on 8751.
- A container started with `DATABASE_URL=postgresql://...` exited 1 and named `infra/migrations/0001_rooms.sql`.
- `./scripts/apply_postgres_migration.sh` exited 1 because `psql` is not installed. A `sqlite:///` URL is rejected by that script. The SQL file was not applied.
- `docker compose` is not installed (the plugin is missing), so `infra/docker-compose.yml` was not started and the optional Postgres service was not pulled.

## Production

Not deployed. No public URL, DNS name, TLS certificate, or Cloudflare Pages project exists. No Origin namespace was configured.

On a machine that already has a running Docker engine and the compose plugin:

```bash
docker compose -f infra/docker-compose.yml up --build -d
curl -sS http://127.0.0.1:8741/ready
```

That stack is the API plus a SQLite file on the `market-data` volume. It is not the public service. The `postgres` and `web` profiles stay off unless you ask for them:

```bash
docker compose -f infra/docker-compose.yml --profile postgres up -d
docker compose -f infra/docker-compose.yml --profile web up -d
```

The web profile serves `build/web` and fails until `./scripts/export_web.sh` has been run. The API does not connect to Postgres. Change `POSTGRES_PASSWORD` before port 5432 is reachable past the machine. Do not put that URL in the API environment. The process will refuse it.

`MD_REPO_ROOT=/app` is set in the image so the installed package can still read `/app/shared`. Leave it unset in a checkout.

## Database migration

SQLite schema version is `1`. Opening a database creates `schema_meta` and `rooms`, or upgrades a version `0` file in place. Any other version is rejected. There is no separate SQLite migration command.

`infra/migrations/0001_rooms.sql` is the same two tables for PostgreSQL. Apply it only when you are preparing a database the current process will not open:

```bash
DATABASE_URL=postgresql://USER:PASSWORD@HOST:5432/market ./scripts/apply_postgres_migration.sh
```

That needs `psql`. It was not run here. After it succeeds, keep the API on SQLite until a driver exists.

## Web export

```bash
./scripts/export_web.sh
python3 scripts/serve_web.py --directory build/web --host 127.0.0.1 --port 8097
```

For a static host, upload every file in `build/web/`. Set:

```
/index.html
  Cache-Control: no-cache
/*.js
  Cache-Control: no-cache
/*.wasm
  Content-Type: application/wasm
  Cache-Control: public, max-age=3600, must-revalidate
/*.pck
  Content-Type: application/octet-stream
  Cache-Control: public, max-age=3600, must-revalidate
```

Do not add COOP or COEP for this single-threaded export.

## What a public deploy still requires

1. Run the API on an always-on host that keeps WebSocket connections open. Do not put it on a short-lived serverless function. Terminate TLS in front of it.
2. Set `MD_CORS_ORIGINS` to the exact `https` origin of the static page. Restart the API.
3. Upload `build/web/` with the MIME and cache headers above.
4. Open `https://<pages-host>/index.html?server=https://<api-host>`. The client then uses `wss`.
5. Play from current desktop Chrome, Firefox, and Safari before claiming those browsers. Mobile is still untested.
6. Two to four people must finish a real match on that invite URL, including a reconnect, before section 10 of the spec is met.

No secret belongs in the repository. `.env.example` lists the variable names only.
