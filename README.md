# Market Dominion

A fictional tile-and-market strategy game for 2–4 players. Cash, shares, and BYTE coins are game currency. This repository does not take bets, hold wallets, or trade real assets.

**Client 0.20.0 is a browser-beta slice.** The page is a Godot 4.7.2 Compatibility single-threaded export. The API is a long-lived FastAPI process with SQLite. Headless Chrome loaded the canvas on loopback HTTP. There is no public HTTPS site. See [TASKS.md](TASKS.md), [docs/ROADMAP_M9_M12.md](docs/ROADMAP_M9_M12.md), and [RUNBOOK.md](RUNBOOK.md).

## Tested Godot build

Pinned and executed in this checkout:

`4.7.2.stable.official.ed1daf0bf`

That is the Godot 4.7 stable line (4.7.2, 18 August 2026). The project uses GDScript and the Compatibility renderer. The web preset is single-threaded.

Linux editor binary used by `scripts/check_client.sh`:

- URL: `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`
- Zip SHA-512: `9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65`

Export templates used by `scripts/export_web.sh`:

- URL: `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz`
- Archive SHA-512: `ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079`
- Installed to `~/.local/share/godot/export_templates/4.7.2.stable/` (needs `web_nothreads_release.zip`)

## Run locally

Requirements: Python 3.12, `curl`, `unzip`, and `sha512sum`. The client check downloads the Godot binary on first use (about 74 MB) into `.tools/`, which is gitignored.

```bash
./scripts/dev.sh
```

The API listens on `http://127.0.0.1:8741`.

- Health: `http://127.0.0.1:8741/health`
- Readiness: `http://127.0.0.1:8741/ready`
- OpenAPI: `http://127.0.0.1:8741/docs`
- Schema: `http://127.0.0.1:8741/v1/protocol/schema`

`POST /v1/protocol/commands/validate` checks a command envelope and does not play a move (`applied` is false).

`POST /v1/rooms/commands` creates a room, joins by invite code, and plays. After create or join, the client opens `ws://127.0.0.1:8741/v1/rooms/ws` with `match_id` and `session_token`. An `https` server URL uses `wss`.

In a second terminal:

```bash
./scripts/check_client.sh
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path client
```

The Godot window is the local table, plus an Online room panel. Check "One human versus computers" to keep one seat and add Ada, Bo, or Cy. The difficulty starts on Normal. Easy looks one tile ahead and trades little. Normal and Hard look five tiles ahead, trade shares and BYTE, and Hard will also buy a larger company to take the lead. Pass-and-play is the unchecked setup and always uses Normal. The price column lists the last four actions. A trade or a round event flashes that price, and the end of the match opens standings with Play again (same seed and difficulty) or Back to lobby. Keys: 1–5 select a tile, Enter places it, arrow keys move along the hand, R opens the rules, Esc closes a panel, `[` and `]` change text size, M toggles reduced motion. Online, two windows share one invite code. Each window shows only its own tiles. The host Start control stays off until every joined player is ready. Verified desktop captures include `docs/m6-table.png`, `docs/m6-rules.png`, `docs/m6-lobby.png`, and `docs/m6-online.png`. `docs/m6-narrow.png` is a 420×800 window, not a device.

## Web export

```bash
./scripts/export_web.sh
./scripts/smoke_web.sh
```

`export_web.sh` checks the template archive, installs it when `web_nothreads_release.zip` is missing, copies `shared/` into `client/export_shared/` (gitignored), and runs:

```bash
godot --headless --path client --export-release "Web" build/web/index.html
```

The preset is `client/export_presets.cfg`. `variant/thread_support` is false. The renderer is Compatibility. `build/` is gitignored. This checkout produced `build/web/index.html`, `index.js` (274K), `index.wasm` (38M), and `index.pck` (182K, including the shared JSON). `index.html` sets `GODOT_THREADS_ENABLED` to false and `ensureCrossOriginIsolationHeaders` to false, so this build does not need `Cross-Origin-Opener-Policy` or `Cross-Origin-Embedder-Policy`. A later threaded export would need both headers.

`scripts/serve_web.py` is the local static server. Python's stock server would label `.wasm` as `application/octet-stream`, which browsers can refuse to compile. Serve these types:

| File | Content-Type | Cache-Control |
| --- | --- | --- |
| `index.html`, `*.js` | `text/html` or `text/javascript` | `no-cache` |
| `*.wasm` | `application/wasm` | `public, max-age=3600, must-revalidate` |
| `*.pck` | `application/octet-stream` | `public, max-age=3600, must-revalidate` |

The filenames are not content-hashed. Do not mark them immutable. `./scripts/export_web.sh` also writes `md-config.js`, `BUILD.txt`, and `_headers`. `md-config.js` does not set a loopback server. Set `window.MD_SERVER` on the host you publish, or open the page with `?server=`. `./scripts/smoke_web.sh` checked the loopback headers and exited. `.venv/bin/python scripts/browser_smoke.py` then loaded that page in headless Chrome far enough to construct Godot's `Engine`. That was not a match and it was not HTTPS.

A page can point at the API with `index.html?server=https://api.example`. Only `http://` and `https://` are accepted. An `https` API URL makes the client open `wss`. The desktop game ignores the query and still defaults to `http://127.0.0.1:8741`. The web build leaves the server field empty unless the query or `window.MD_SERVER` sets it. Copy invitation link keeps `server` and adds `invite`. It strips `session_token` and `token`.

On the web build the sibling `shared/` directory is not on disk. The export copies it into the pack at `res://export_shared/`, and the client reads that when the external path is missing.

GitHub Actions is defined in `.github/workflows/ci.yml`. The server job runs pytest. The client job runs `scripts/check_client.sh`. The web job runs `scripts/export_web.sh`, the MIME smoke, a headless Chrome load, and uploads `build/web`. That workflow was not executed by GitHub from this environment. A green export is not a finished match. Examples for Cloudflare Pages headers and a Caddy reverse proxy are in `infra/deploy/`. Production variable names are in `infra/deploy/production.env.example`. No hosting account was configured.

## Container

`infra/Dockerfile` builds the API. In this environment the image `market-dominion-api:local` (`0e9f554b751a`) was built and started with `docker run -p 8751:8741`. `GET /health` and `GET /ready` succeeded, a room create returned 200, the process uid was 10001, and `/data/market.db` was owned by that uid. The container was removed afterward. `docker compose` is not installed here, so `infra/docker-compose.yml` was not started.

The API stores rooms in SQLite. `DATABASE_URL=sqlite:///...` selects that file. `postgres://` and `postgresql://` abort startup and name `infra/migrations/0001_rooms.sql`. The process does not open PostgreSQL. The compose file has a `postgres` profile with the local password `market`. That password is not a production secret, and the API service does not use it. `psql` is not installed here, so the migration was not applied.

Copy `.env.example` into the host environment. Do not commit `.env`. Empty `MD_CORS_ORIGINS` leaves browser cross-origin calls blocked and lets the desktop client connect. A hosted page must set that list to its exact origin.

## Tests

```bash
./scripts/test.sh
```

That installs the dev extra, runs `pytest`, and runs the Godot headless check. Server-only:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -e ".[dev]"
.venv/bin/python -m pytest -q
```

Regenerate the coordinate list and the sample lobby snapshot after a deliberate builder change:

```bash
python3 scripts/dump_fixtures.py
```

## Layout

| Path | Role |
| --- | --- |
| `client/` | Godot 4 GDScript app |
| `server/` | FastAPI process and Python rules kernels |
| `shared/protocol/schema.json` | Command, event, and public-state contract |
| `shared/fixtures/` | Golden vectors and sample envelopes |
| `server/tests/`, `tests/e2e/` | Automated tests |
| `infra/` | Dockerfile, compose file, entrypoint, Postgres DDL |
| `build/web/` | Godot web export (gitignored; produced locally) |
| `.github/workflows/ci.yml` | Pytest, Godot headless check, and a web export job. The web job was not run from this environment |

More detail: [RULES.md](RULES.md), [ARCHITECTURE.md](ARCHITECTURE.md), [RUNBOOK.md](RUNBOOK.md), [CHANGELOG.md](CHANGELOG.md).

## Currency

Every dollar figure is a fictional integer. There is no deposit, payout to a bank, token, or blockchain.
