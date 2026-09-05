#!/bin/sh
set -eu
# First-install helper; invoke with sh scripts/init-config.sh from the repo root.
cd "$(dirname "$0")/.."
command -v openssl >/dev/null || { echo 'openssl is required to generate random credentials.' >&2; exit 1; }
umask 077
for name in mysql-root-password mysql-app-password portal-app-secret cafe2-central-jdbc.properties cafe2-worker-jdbc.properties cafe2-local-jdbc.properties; do
    if [ -e "secrets/$name" ]; then
        echo "Existing secret file $name; refusing to overwrite." >&2
        exit 1
    fi
done
mkdir -p secrets
chmod 700 secrets
# noclobber also protects against concurrent creation after the check above.
set -C
openssl rand -hex 32 > secrets/mysql-root-password
openssl rand -hex 32 > secrets/mysql-app-password
openssl rand -hex 32 > secrets/portal-app-secret
app_password=$(tr -d '\r\n' < secrets/mysql-app-password)
for mode in central worker local; do
    database=CAFEWORKER
    if [ "$mode" = central ]; then database=CAFECENTRAL; fi
    printf 'jdbc.url=jdbc:mysql://mysql:3306/%s?characterEncoding=UTF-8&serverTimezone=UTC&allowPublicKeyRetrieval=true&useSSL=false\njdbc.username=cafe2\njdbc.password=%s\njdbc.driver=com.mysql.cj.jdbc.Driver\n' "$database" "$app_password" > "secrets/cafe2-$mode-jdbc.properties"
done
echo 'Created six local secret files. No values printed. Configure .env before starting.'
