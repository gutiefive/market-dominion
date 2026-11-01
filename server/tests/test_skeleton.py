"""Repository layout required by the M0 foundation gate."""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED = [
    "README.md",
    "RULES.md",
    "TASKS.md",
    "CHANGELOG.md",
    "ARCHITECTURE.md",
    "RUNBOOK.md",
    "Makefile",
    "pyproject.toml",
    ".github/workflows/ci.yml",
    "client/project.godot",
    "client/icon.svg",
    "client/scenes/main.tscn",
    "client/scripts/ui/foundation_screen.gd",
    "client/scripts/ui/match_screen.gd",
    "client/scripts/ui/board_grid.gd",
    "client/scripts/domain/rng.gd",
    "client/scripts/domain/offline_match.gd",
    "client/tests/m1_check.gd",
    "client/tests/m2_check.gd",
    "client/tests/m3_check.gd",
    "client/tests/m4_check.gd",
    "client/scripts/domain/board.gd",
    "client/scripts/domain/mergers.gd",
    "client/scripts/domain/pricing.gd",
    "client/scripts/domain/coordinates.gd",
    "client/scripts/domain/events.gd",
    "client/scripts/domain/scoring.gd",
    "client/scripts/domain/tiles.gd",
    "client/scripts/net/shared_files.gd",
    "client/tests/m0_check.gd",
    "docs/m0-foundation.png",
    "docs/m0-narrow.png",
    "docs/m1-opening.png",
    "docs/m1-placed.png",
    "docs/m1-narrow.png",
    "docs/m2-economy.png",
    "docs/m3-merger.png",
    "docs/m3-tie.png",
    "server/app/main.py",
    "server/app/contract.py",
    "server/app/api/health.py",
    "server/app/api/protocol.py",
    "server/app/domain/pricing.py",
    "server/app/domain/rng.py",
    "server/app/domain/offline.py",
    "server/tests/test_offline.py",
    "server/tests/test_economy.py",
    "server/tests/test_mergers.py",
    "server/tests/test_events_end.py",
    "server/app/domain/board.py",
    "server/app/domain/mergers.py",
    "server/app/domain/invariants.py",
    "server/app/persistence/sqlite.py",
    "shared/protocol/schema.json",
    "shared/fixtures/rules_constants.json",
    "shared/fixtures/corporations.json",
    "shared/fixtures/round_events.json",
    "shared/fixtures/golden_events.json",
    "shared/fixtures/coordinates.json",
    "shared/fixtures/sample_lobby_state.json",
    "shared/fixtures/golden_prices.json",
    "shared/fixtures/golden_rng.json",
    "shared/fixtures/golden_deals.json",
    "shared/fixtures/golden_placement.json",
    "shared/fixtures/golden_byte.json",
    "shared/fixtures/commands/place_tile.json",
    "infra/docker-compose.yml",
    "infra/Dockerfile",
    "infra/deploy/README.md",
    ".dockerignore",
    "scripts/dev.sh",
    "scripts/test.sh",
    "scripts/check_client.sh",
    "scripts/dump_fixtures.py",
    "tests/e2e/test_http_smoke.py",
]


def test_required_paths_exist():
    missing = [path for path in REQUIRED if not (ROOT / path).exists()]
    assert missing == []


def test_shell_scripts_parse():
    for name in ("scripts/dev.sh", "scripts/test.sh", "scripts/check_client.sh"):
        subprocess.run(["bash", "-n", str(ROOT / name)], check=True)


def test_readme_pins_the_tested_godot_build():
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    project = (ROOT / "client" / "project.godot").read_text(encoding="utf-8")
    assert "4.7.2.stable.official.ed1daf0bf" in readme
    assert "4.7.2" in readme
    assert "gl_compatibility" in project
    assert "4.7" in project


def test_dev_script_mentions_the_documented_port():
    rules = (ROOT / "shared" / "fixtures" / "rules_constants.json").read_text(encoding="utf-8")
    script = (ROOT / "scripts" / "dev.sh").read_text(encoding="utf-8")
    assert '"api_port": 8741' in rules
    assert "8741" in script


def test_ci_runs_pytest_and_pins_godot():
    workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    assert "pytest" in workflow
    assert "4.7.2" in workflow
    assert "check_client.sh" in workflow
