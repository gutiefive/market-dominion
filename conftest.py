"""Shared pytest fixtures."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import create_app


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.setenv("MD_DATABASE_PATH", str(tmp_path / "market.db"))
    monkeypatch.delenv("MD_CORS_ORIGINS", raising=False)
    application = create_app()
    with TestClient(application) as test_client:
        yield test_client
