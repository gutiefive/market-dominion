# Deployment notes

M0 does not deploy anything. No production URL was tested.

The intended later shape, from the game specification, is:

- Static Godot web export (Compatibility renderer, GDScript) on a static host such as Cloudflare Pages.
- The FastAPI process on a host that keeps WebSocket connections open. Do not put the authoritative server on a short-lived serverless function.
- SQLite schema version 1 stores rooms for local play. PostgreSQL is still the intended production database. That migration does not exist yet. The Godot client will speak `wss` when the server URL is `https`, but no TLS origin is configured.

`infra/Dockerfile` and `infra/docker-compose.yml` are local packaging for the API. This environment did not have Docker, so the image was not built and the compose file was not started. Do not treat them as a verified deploy.

Secrets, `DATABASE_URL`, HTTPS, and WSS origins are not configured. There is no paid service requirement for M0.
