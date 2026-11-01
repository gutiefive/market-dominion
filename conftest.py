"""Shared pytest fixtures."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import create_app


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("MD_DATABASE_PATH", str(tmp_path / "market.db"))
    application = create_app()
    with TestClient(application) as test_client:
        yield test_client
