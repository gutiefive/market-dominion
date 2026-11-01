# Runbook

## Local API

```bash
./scripts/dev.sh
```

- Binds `127.0.0.1:8741` unless `MD_PORT` is set.
- Creates `.venv` and installs the package editable.
- SQLite path: `server/data/market.db`, or `MD_DATABASE_PATH`.
- Stop with Ctrl-C. The schema_version 0 file can be deleted; the next `/ready` recreates it.

Checks:

```bash
curl -sS http://127.0.0.1:8741/health
curl -sS http://127.0.0.1:8741/ready
```

`/ready` returns `database_schema_version` `0` and `currency` `fictional`.

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

The check imports the project headless and must print `M0_CLIENT_OK`. The window is the foundation screen: navy background, contract numbers, a reload button. `R` reloads. `Esc` quits. Window stretch is disabled so that screen uses the real window size; under 760 px the cards stack in one column. Verified captures: `docs/m0-foundation.png` (1280×720) and `docs/m0-narrow.png` (420×800).

Set `GODOT_BIN` to skip the download. The script still refuses a binary whose `--version` output is not `4.7.2.stable.official.ed1daf0bf`, because `client/tests/m0_check.gd` asserts that string.

Screenshot (needs a display; not part of CI):

```bash
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path client --display-driver x11 \
  --audio-driver Dummy -- --screenshot /tmp/market-dominion-m0.png
```

## Tests and CI

```bash
./scripts/test.sh
```

GitHub Actions workflow `.github/workflows/ci.yml` runs pytest on Python 3.12 and `scripts/check_client.sh` on the 4.7.2 Linux binary.

## Logs and data

Uvicorn writes access logs to the terminal. There is no remote error sink. The only database table is `schema_meta`. Deleting the db file is the rollback for M0.

## Production

Not deployed. No HTTPS, WSS, or hosted database was configured. `docker compose -f infra/docker-compose.yml up --build` is the intended local container path and was not executed in the M0 environment because Docker was not installed. Do not describe that compose file as a running stack.

## Web export

Not run. The project sets `renderer/rendering_method` to `gl_compatibility` for desktop, mobile, and web. Export presets and templates are a later milestone.
