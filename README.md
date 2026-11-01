# Market Dominion

A fictional tile-and-market strategy game for 2–4 players. Cash, shares, and BYTE coins are game currency. This repository does not take bets, hold wallets, or trade real assets.

**M2 is a local pass-and-play table.** The board deals tiles, founds and grows companies, and trades shares and BYTE on one device. Mergers, round events, and online rooms are not implemented. See [TASKS.md](TASKS.md).

## Tested Godot build

Pinned and executed in this checkout:

`4.7.2.stable.official.ed1daf0bf`

That is the Godot 4.7 stable line (4.7.2, 18 August 2026). The project uses GDScript and the Compatibility renderer so a later browser export stays possible. No web export has been produced.

Linux editor binary used by `scripts/check_client.sh`:

- URL: `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`
- Zip SHA-512: `9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65`

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

In a second terminal:

```bash
./scripts/check_client.sh
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path client
```

The Godot window is the local table. Deal with a seed, pass the device, place a tile, choose a brand when a chain reaches size 2, then take up to two market actions. Hands stay covered between seats. Verified captures: `docs/m2-economy.png` (founding, growth, and a share purchase), `docs/m1-opening.png`, `docs/m1-placed.png` (1280×720), and `docs/m1-narrow.png` (420×800).

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
| `infra/` | Dockerfile and compose file (not executed here) |
| `.github/workflows/ci.yml` | Pytest plus the Godot headless check |

More detail: [RULES.md](RULES.md), [ARCHITECTURE.md](ARCHITECTURE.md), [RUNBOOK.md](RUNBOOK.md), [CHANGELOG.md](CHANGELOG.md).

## Currency

Every dollar figure is a fictional integer. There is no deposit, payout to a bank, token, or blockchain.
