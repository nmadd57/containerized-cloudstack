#!/bin/bash
set -euo pipefail

# ── defaults ──────────────────────────────────────────────────────────────────
DB_HOST="${DB_HOST:-mariadb}"
DB_PORT="${DB_PORT:-3306}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:?DB_ROOT_PASSWORD is required}"
DB_USER="${DB_USER:-cloud}"
DB_PASSWORD="${DB_PASSWORD:?DB_PASSWORD is required}"
DB_NAME="${DB_NAME:-cloud}"
CLOUDSTACK_HOME="${CLOUDSTACK_HOME:-/cloudstack}"

# ── wait for MariaDB ──────────────────────────────────────────────────────────
echo "Waiting for MariaDB at ${DB_HOST}:${DB_PORT}..."
until mysqladmin ping -h "${DB_HOST}" -P "${DB_PORT}" \
        -u root -p"${DB_ROOT_PASSWORD}" --silent 2>/dev/null; do
    sleep 5
done
echo "MariaDB ready."

# ── first-run schema deployment ───────────────────────────────────────────────
DB_EXISTS=$(mysql -h "${DB_HOST}" -P "${DB_PORT}" \
    -u root -p"${DB_ROOT_PASSWORD}" \
    -sse "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}';" \
    2>/dev/null)

if [ "${DB_EXISTS}" = "0" ]; then
    echo "Deploying CloudStack database schema..."

    # create databases and grant privileges
    mysql -h "${DB_HOST}" -P "${DB_PORT}" -u root -p"${DB_ROOT_PASSWORD}" \
        -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
    mysql -h "${DB_HOST}" -P "${DB_PORT}" -u root -p"${DB_ROOT_PASSWORD}" \
        -e "CREATE DATABASE IF NOT EXISTS cloud_usage;"
    mysql -h "${DB_HOST}" -P "${DB_PORT}" -u root -p"${DB_ROOT_PASSWORD}" \
        -e "GRANT ALL ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';"
    mysql -h "${DB_HOST}" -P "${DB_PORT}" -u root -p"${DB_ROOT_PASSWORD}" \
        -e "GRANT ALL ON cloud_usage.* TO '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';"
    mysql -h "${DB_HOST}" -P "${DB_PORT}" -u root -p"${DB_ROOT_PASSWORD}" \
        -e "FLUSH PRIVILEGES;"

    # apply schema in order
    for sql_file in \
        setup/db/create-schema.sql \
        setup/db/create-schema-premium.sql \
        setup/db/create-usage-schema.sql \
        setup/db/templates.sql; do
        if [ -f "${CLOUDSTACK_HOME}/${sql_file}" ]; then
            echo "  applying ${sql_file}..."
            mysql -h "${DB_HOST}" -P "${DB_PORT}" \
                -u root -p"${DB_ROOT_PASSWORD}" \
                "${DB_NAME}" \
                < "${CLOUDSTACK_HOME}/${sql_file}"
        fi
    done

    # usage schema goes into cloud_usage
    for sql_file in setup/db/create-usage-schema.sql; do
        if [ -f "${CLOUDSTACK_HOME}/${sql_file}" ]; then
            echo "  applying ${sql_file} to cloud_usage..."
            mysql -h "${DB_HOST}" -P "${DB_PORT}" \
                -u root -p"${DB_ROOT_PASSWORD}" \
                cloud_usage \
                < "${CLOUDSTACK_HOME}/${sql_file}" 2>/dev/null || true
        fi
    done

    echo "Schema deployment complete."
fi

# ── write db.properties for jetty ────────────────────────────────────────────
# jetty reads from client/target/conf/ when built with the developer profile
mkdir -p "${CLOUDSTACK_HOME}/client/target/conf"
cat > "${CLOUDSTACK_HOME}/client/target/conf/db.properties" <<EOF
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
db.usage.url=jdbc:mysql://${DB_HOST}:${DB_PORT}/cloud_usage

db.simulator.username=${DB_USER}
db.simulator.password=${DB_PASSWORD}
db.simulator.host=${DB_HOST}
db.simulator.port=${DB_PORT}
db.simulator.name=cloud
db.simulator.driver=com.mysql.jdbc.Driver
db.simulator.url=jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}
EOF

echo "Starting CloudStack management server via supervisord..."
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/cloudstack.conf
