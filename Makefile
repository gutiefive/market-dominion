.PHONY: dev test client-check fixtures web smoke-web

dev:
	./scripts/dev.sh

test:
	./scripts/test.sh

client-check:
	./scripts/check_client.sh

fixtures:
	python3 scripts/dump_fixtures.py

web:
	./scripts/export_web.sh

smoke-web:
	./scripts/smoke_web.sh
