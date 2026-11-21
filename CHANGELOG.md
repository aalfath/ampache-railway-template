# Changelog

## 8.4.0-railway.1 (2026-11-21)

- First release: Ampache 8.4.0 (`ampache/ampache:nosql8.4.0@sha256:50db708d0efab29433a7d9a379cb88bdbe6d7b8ec046599eb518982d1d484213`) with MariaDB 11.4.13 (`mariadb:11.4.13@sha256:a8992b5e5404d11e03c54a31d0c1bdea3fd116d283aa6d1a627551f29045309b`).
- Unattended first install: schema, admin user from `AMPACHE_ADMIN_USER` / `AMPACHE_ADMIN_PASSWORD`, a `music` catalog at `/media/music` with uploads enabled.
- Config, backups and media on the `/data` volume; health check on `/healthz` (configured and database reachable).
