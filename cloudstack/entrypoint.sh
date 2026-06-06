#!/bin/bash
set -euo pipefail

DB_HOST="${DB_HOST:-mariadb}"
DB_PORT="${DB_PORT:-3306}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:?DB_ROOT_PASSWORD is required}"
DB_USER="${DB_USER:-cloud}"
DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD is required}"
DB_NAME="${DB_NAME:-cloud}"

# ── runtime directories ───────────────────────────────────────────────────────
mkdir -p /var/log/cloudstack/management /var/run /etc/cloudstack/management

# ── wait for MariaDB ──────────────────────────────────────────────────────────
echo "Waiting for MariaDB at ${DB_HOST}:${DB_PORT}..."
until mysqladmin ping -h "${DB_HOST}" -P "${DB_PORT}" \
        -u root -p"${DB_ROOT_PASSWORD}" --silent 2>/dev/null; do
    sleep 3
done
echo "MariaDB ready."

# ── first-run: deploy schema and configure management server ──────────────────
DB_EXISTS=$(mysql -h "${DB_HOST}" -P "${DB_PORT}" \
    -u root -p"${DB_ROOT_PASSWORD}" \
    -sse "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}';" \
    2>/dev/null)

if [ "${DB_EXISTS}" = "0" ]; then
    echo "Deploying CloudStack database schema..."
    cloudstack-setup-databases \
        "${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}" \
        --deploy-as=root:"${DB_ROOT_PASSWORD}"

    echo "Configuring management server..."
    cloudstack-setup-management --no-start

    echo "First-run setup complete."
fi

# ── start management server ───────────────────────────────────────────────────
# Source the env file that defines JAVA_OPTS, CLASSPATH, and BOOTSTRAP_CLASS
# then exec Java as PID 1 so Docker signals are handled correctly.
echo "Starting CloudStack management server..."
# shellcheck disable=SC1091
. /etc/default/cloudstack-management

cd /var/log/cloudstack/management
exec /usr/bin/java \
    ${JAVA_OPTS} \
    -cp "${CLASSPATH}" \
    ${BOOTSTRAP_CLASS}
