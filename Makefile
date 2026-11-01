.PHONY: dev test client-check fixtures

dev:
	./scripts/dev.sh

test:
	./scripts/test.sh

client-check:
	./scripts/check_client.sh

fixtures:
	python3 scripts/dump_fixtures.py
