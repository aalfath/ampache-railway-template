[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/ampache-1?utm_medium=integration&utm_source=button&utm_campaign=ampache)

# Ampache on Railway

One-click [Ampache](https://ampache.org) for [Railway](https://railway.com): Ampache **8.4.0** (web music and video streaming server with a Subsonic, Ampache and Jellyfin-compatible API) with its own MariaDB, every piece of state on a volume, a generated admin password, a health check, and update notices when this repo bumps the version.

## What the template deploys

| Service | Source | What it does | Volume |
|---|---|---|---|
| `Ampache` | this repo (`Dockerfile`) | Ampache 8.4.0 on Apache + PHP 8.5, public HTTPS domain, hourly maintenance cron, watches the music folder for new files | `/data` (config, database backups, media) |
| `MariaDB` | `mariadb:11.4.13` (pinned by digest) | Ampache's database, private network only | `/var/lib/mysql` |

The image is Ampache's official [`ampache/ampache:nosql8.4.0`](https://hub.docker.com/r/ampache/ampache) (the variant without a bundled database), pinned by digest. This repo adds a small wrapper in `rootfs/`:

- `railway-start.sh`: links `/var/www/config`, `/var/www/backup` and `/media` to the `/data` volume, makes Apache listen on `PORT`, waits for MariaDB, installs or upgrades Ampache, then runs Apache. If Apache stops unexpectedly the container exits non-zero, so Railway restarts it.
- `railway-install.sh` (first start only): creates the database schema, the admin user from `AMPACHE_ADMIN_USER` / `AMPACHE_ADMIN_PASSWORD`, a `music` catalog at `/media/music`, and enables web uploads into it.
- `railway-config.php`: keeps the database settings in `ampache.cfg.php` in line with the Railway variables and sets Railway's HTTPS settings (`force_ssl`, secure cookies, port 443).
- Apache is limited to 10 workers and PHP to 384 MB per request, so Ampache runs within a 0.5 GB service (Railway's Free plan). Uploads up to 512 MB per file.

## Variables

| Service | Variable | Default | Notes |
|---|---|---|---|
| Ampache | `AMPACHE_ADMIN_USER` | `admin` | First admin's username (first start only) |
| Ampache | `AMPACHE_ADMIN_PASSWORD` | generated, 24 characters | First admin's password; read it in the service's Variables tab |
| Ampache | `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | references to `MariaDB` | Private network |
| Ampache | `PORT` | `80` | Apache port behind the Railway domain |
| MariaDB | `MARIADB_DATABASE`, `MARIADB_USER` | `ampache` | Created on MariaDB's first start |
| MariaDB | `MARIADB_PASSWORD`, `MARIADB_ROOT_PASSWORD` | generated, 32 characters | |

Optional, set on the `Ampache` service if you need them: `AMPACHE_ADMIN_EMAIL` (first start only), `APACHE_MAX_WORKERS` (default `10`), `PHP_MEMORY_LIMIT` (default `384M`), `DISABLE_INOTIFYWAIT_CLEAN=1` (don't remove missing files from the catalog automatically). Other settings (Last.fm keys, email, transcoding) live in `/data/config/ampache.cfg.php` or in Ampache's admin pages.

## After deploy

1. Open the `Ampache` service's domain (the first start takes about 30 seconds).
2. Log in with `AMPACHE_ADMIN_USER` and the `AMPACHE_ADMIN_PASSWORD` value from the Variables tab.
3. Add music: upload files in the web UI (**Upload** in the sidebar), or copy them into `/media/music` (for example with `railway ssh`). New files in `/media/music` are picked up automatically; **Admin > Catalogs > music > Add new** rescans by hand.
4. Point a Subsonic-compatible app (DSub, Symfonium, play:Sub, Feishin…) at `https://YOUR-DOMAIN` with your Ampache username and password, or use the Ampache API.

## Updates

A merge to this repo's `main` (a new pinned Ampache version) shows as an "update available" notice in your Railway project. Read [CHANGELOG.md](CHANGELOG.md) first, back up the database (`backup-db.sh` in the Ampache service's shell writes a dump to `/data/backup`), then apply it. Ampache applies its database and config migrations on every start.

## Resources

Tested with 0.5 GB RAM / 1 vCPU per service. Idle use is about 30 MB (Ampache) and 110 MB (MariaDB). Large libraries and transcoding need more RAM and CPU; storage grows with your music on the `/data` volume.
