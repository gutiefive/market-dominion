# Deployment notes

M0 does not deploy anything. No production URL was tested.

The intended later shape, from the game specification, is:

- Static Godot web export (Compatibility renderer, GDScript) on a static host such as Cloudflare Pages.
- The FastAPI process on a host that keeps WebSocket connections open. Do not put the authoritative server on a short-lived serverless function.
- SQLite is the local file created by the schema_version 0 stub. PostgreSQL is the production database once matches are persisted. That migration does not exist yet.

`infra/Dockerfile` and `infra/docker-compose.yml` are local packaging for the API. This environment did not have Docker, so the image was not built and the compose file was not started. Do not treat them as a verified deploy.

Secrets, `DATABASE_URL`, HTTPS, and WSS origins are not configured. There is no paid service requirement for M0.
