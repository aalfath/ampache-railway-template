#!/bin/bash
# Railway start script for Ampache: prepares the /data volume, installs or upgrades Ampache,
# then runs Apache in the foreground. Any unexpected stop exits non-zero so Railway restarts it.
set -euo pipefail

log() { echo "=> [railway] $*"; }

export PORT="${PORT:-80}"
export DB_PORT="${DB_PORT:-3306}"
export APACHE_MAX_WORKERS="${APACHE_MAX_WORKERS:-10}"

for v in DB_HOST DB_NAME DB_USER DB_PASSWORD; do
    if [ -z "${!v:-}" ]; then
        log "ERROR: $v is not set. It should reference the MariaDB service."
        exit 1
    fi
done

# 1. Persistent layout on the Railway volume mounted at /data.
#    /var/www/config, /var/www/backup and /media are symlinks into /data (see Dockerfile).
mkdir -p /data/config /data/backup /data/media/music
chown www-data:www-data /data /data/config /data/backup /data/media /data/media/music
chmod 0775 /data/media /data/media/music
cp -p /var/tmp/*.dist /data/config/
chown -R www-data:www-data /data/config

# 2. Apache listens on Railway's PORT.
sed -ri "s/^Listen [0-9]+$/Listen ${PORT}/" /etc/apache2/ports.conf

# 3. Wait for MariaDB on the private network (up to 3 minutes).
export MYSQL_PWD="$DB_PASSWORD"
for i in $(seq 1 90); do
    if mariadb -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -e 'SELECT 1' "$DB_NAME" >/dev/null 2>&1; then
        break
    fi
    if [ "$i" = 90 ]; then
        log "ERROR: MariaDB at $DB_HOST:$DB_PORT did not answer in time"
        exit 1
    fi
    log "waiting for MariaDB at $DB_HOST:$DB_PORT ($i)"
    sleep 2
done
TABLES=$(mariadb -N -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE()" "$DB_NAME")
unset MYSQL_PWD

CONFIG=/data/config/ampache.cfg.php
as_www() { setpriv --reuid=www-data --regid=www-data --init-groups "$@"; }

# 4. Install, or recover, or upgrade.
if [ ! -f "$CONFIG" ] && [ "$TABLES" = 0 ]; then
    railway-install.sh
elif [ ! -f "$CONFIG" ]; then
    log "Ampache tables found in $DB_NAME but no config file: writing a new config (data kept)"
    as_www php /usr/local/bin/railway-config.php --new
fi
# Keep the database settings in the config in line with the Railway variables.
as_www php /usr/local/bin/railway-config.php
log "applying pending config and database updates (if any)"
as_www php /var/www/bin/cli admin:updateConfigFile -e >/dev/null || true
as_www php /var/www/bin/cli admin:updateDatabase -e | grep -E 'version|Update|Error|No Update' || true

# 5. Background helpers from the upstream image: hourly maintenance cron and the media folder watcher.
cron
DISABLE_INOTIFYWAIT_CLEAN="${DISABLE_INOTIFYWAIT_CLEAN:-0}" /usr/local/bin/inotifywait.sh >/dev/null 2>&1 &

# 6. Apache in the foreground.
rm -f /var/run/apache2/apache2.pid
apachectl -DFOREGROUND &
APACHE_PID=$!
stopping=0
trap 'stopping=1; log "stopping"; apachectl -k graceful-stop 2>/dev/null || kill -TERM "$APACHE_PID"; ' TERM INT
log "Ampache is starting on port $PORT"
set +e
wait "$APACHE_PID"; rc=$?
while [ "$stopping" = 1 ] && kill -0 "$APACHE_PID" 2>/dev/null; do wait "$APACHE_PID"; rc=$?; done
set -e
if [ "$stopping" = 1 ]; then
    exit 0
fi
log "ERROR: Apache stopped unexpectedly (exit $rc)"
exit $(( rc == 0 ? 1 : rc ))
