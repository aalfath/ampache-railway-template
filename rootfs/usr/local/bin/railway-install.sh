#!/bin/bash
# First start only: create the Ampache schema in the empty MariaDB database, the first admin,
# a "music" catalog on the volume, and enable uploads into it.
set -euo pipefail
log() { echo "=> [railway] $*"; }
as_www() { setpriv --reuid=www-data --regid=www-data --init-groups "$@"; }
CLI="php /var/www/bin/cli"

if [ -z "${AMPACHE_ADMIN_PASSWORD:-}" ]; then
    log "ERROR: AMPACHE_ADMIN_PASSWORD is empty; refusing to create an admin without a password"
    exit 1
fi
ADMIN_USER="${AMPACHE_ADMIN_USER:-admin}"

log "installing the Ampache database into $DB_NAME"
# --force: the database exists but is empty (MariaDB created it); the start script checked it has no tables.
out=$(as_www php /var/www/bin/installer install --dbhost "$DB_HOST" --dbport "$DB_PORT" --dbname "$DB_NAME" \
      --dbuser "$DB_USER" --dbpassword "$DB_PASSWORD" --force 2>&1) || true
if [ ! -f /data/config/ampache.cfg.php ]; then
    echo "$out" | grep -v -i password || true
    log "ERROR: the Ampache installer did not write a config file"
    exit 1
fi

log "creating the admin user '$ADMIN_USER'"
args=(-p "$AMPACHE_ADMIN_PASSWORD" -l 100)
[ -n "${AMPACHE_ADMIN_EMAIL:-}" ] && args+=(-e "$AMPACHE_ADMIN_EMAIL")
# The CLI prints the password; keep it out of the logs.
out=$(as_www $CLI admin:addUser "${args[@]}" "$ADMIN_USER" 2>&1) || true
if ! printf '%s' "$out" | grep 'Created' >/dev/null; then
    rm /data/config/ampache.cfg.php
    log "ERROR: creating the admin user failed"
    exit 1
fi

log "creating the 'music' catalog at /media/music and enabling uploads"
as_www $CLI run:addCatalog music /media/music music >/dev/null 2>&1 || log "WARNING: catalog creation failed (create one in Admin > Catalogs)"
as_www php /usr/local/bin/railway-config.php --enable-upload || log "WARNING: could not enable uploads"
log "install done: log in as '$ADMIN_USER' with the AMPACHE_ADMIN_PASSWORD variable"
