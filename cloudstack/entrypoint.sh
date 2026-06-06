#!/bin/bash
set -euo pipefail

DB_HOST="${DB_HOST:-mariadb}"
DB_PORT="${DB_PORT:-3306}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:?DB_ROOT_PASSWORD is required}"
DB_USER="${DB_USER:-cloud}"
DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD is required}"
DB_NAME="${DB_NAME:-cloud}"

# ── wait for MariaDB ──────────────────────────────────────────────────────────
echo "Waiting for MariaDB at ${DB_HOST}:${DB_PORT}..."
until mysqladmin ping -h "${DB_HOST}" -P "${DB_PORT}" \
        -u root -p"${DB_ROOT_PASSWORD}" --silent 2>/dev/null; do
    sleep 3
done
echo "MariaDB ready."

# ── write db.properties ───────────────────────────────────────────────────────
mkdir -p /etc/cloudstack/management
cat > /etc/cloudstack/management/db.properties <<EOF
db.cloud.username=${DB_USER}
db.cloud.password=${DB_PASSWORD}
db.cloud.host=${DB_HOST}
db.cloud.port=${DB_PORT}
db.cloud.name=${DB_NAME}
db.cloud.driver=com.mysql.jdbc.Driver
db.cloud.url=jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?sessionVariables=sql_mode='STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION,ERROR_FOR_DIVISION_BY_ZERO,NO_ZERO_DATE,NO_ZERO_IN_DATE,NO_AUTO_CREATE_USER'&autoReconnect=true

db.usage.username=${DB_USER}
db.usage.password=${DB_PASSWORD}
db.usage.host=${DB_HOST}
db.usage.port=${DB_PORT}
db.usage.name=cloud_usage
db.usage.driver=com.mysql.jdbc.Driver

db.simulator.username=${DB_USER}
db.simulator.password=${DB_PASSWORD}
db.simulator.host=${DB_HOST}
db.simulator.port=${DB_PORT}
db.simulator.name=${DB_NAME}
db.simulator.driver=com.mysql.jdbc.Driver
EOF

# ── first-run schema deployment ───────────────────────────────────────────────
DB_EXISTS=$(mysql -h "${DB_HOST}" -P "${DB_PORT}" \
    -u root -p"${DB_ROOT_PASSWORD}" \
    -sse "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}';" \
    2>/dev/null)

if [ "${DB_EXISTS}" = "0" ]; then
    echo "Deploying CloudStack database schema..."
    cloud-setup-databases "${DB_USER}:${DB_PASSWORD}@${DB_HOST}" \
        --deploy-as=root:"${DB_ROOT_PASSWORD}"
    cloud-setup-management
    echo "Schema deployment complete."
fi

# ── start management server ───────────────────────────────────────────────────
echo "Starting CloudStack management server..."
exec /usr/share/cloudstack-management/bin/catalina.sh run
