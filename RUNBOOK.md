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

The check imports the project headless and must print `M0_CLIENT_OK` through `M5_CLIENT_OK`. The window is the local table. Deal with a seed, pass the device, place one tile, found or grow a company, resolve a merger, then take up to two market actions. Under about 980 px the grid stacks above the market notes, and the page scrolls if the window is shorter than the column. Online room uses the server URL field (default `http://127.0.0.1:8741`). One window creates a room. A second window joins with the match id and invite code, both press Ready, and the host presses Start. Each window shows its own tiles. Verified captures: `docs/m5-room.png`, `docs/m4-event.png`, `docs/m4-score.png`, `docs/m3-merger.png`, `docs/m3-tie.png`, `docs/m2-economy.png`, `docs/m1-opening.png`, `docs/m1-placed.png` (1280×720), and `docs/m1-narrow.png` (420×800).

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

Uvicorn writes access logs to the terminal. There is no remote error sink. Tables are `schema_meta` and `rooms`. Deleting the db file drops rooms and is the local rollback. A version `0` file upgrades to `1` on the next open.

## Production

Not deployed. No HTTPS, WSS, or hosted database was configured. `docker compose -f infra/docker-compose.yml up --build` is the intended local container path and was not executed in the M0 environment because Docker was not installed. Do not describe that compose file as a running stack.

## Web export

Not run. The project sets `renderer/rendering_method` to `gl_compatibility` for desktop, mobile, and web. Export presets and templates are a later milestone.
