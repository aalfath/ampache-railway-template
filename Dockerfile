# Ampache 8.4.0 on Railway.
# Base: Ampache's official image, "nosql" variant (Apache + PHP 8.5 without the bundled MariaDB server;
# the template runs MariaDB as its own service). Pinned by version and multi-arch digest.
# Bump both together and add a CHANGELOG.md entry.
FROM ampache/ampache:nosql8.4.0@sha256:50db708d0efab29433a7d9a379cb88bdbe6d7b8ec046599eb518982d1d484213

COPY rootfs /

# State lives on one Railway volume at /data: config (ampache.cfg.php), database backups and media.
RUN set -eu; \
    cp -p /var/www/config/*.dist /var/tmp/; \
    rm -r /var/www/config /var/www/backup /media; \
    mkdir -p /data; \
    ln -s /data/config /var/www/config; \
    ln -s /data/backup /var/www/backup; \
    ln -s /data/media /media; \
    chmod 0755 /usr/local/bin/railway-config.php /usr/local/bin/railway-start.sh /usr/local/bin/railway-install.sh; \
    a2enconf railway >/dev/null; \
    php -v >/dev/null; \
    test -x /var/www/bin/installer; \
    test -f /var/tmp/ampache.cfg.php.dist

# Railway routes the public domain to PORT; Apache listens on it (80 when unset).
ENV PORT=80 \
    APACHE_MAX_WORKERS=10
EXPOSE 80

# Our start script replaces the base entrypoint (it does the same permission fixes for /data).
ENTRYPOINT ["railway-start.sh"]
CMD []
