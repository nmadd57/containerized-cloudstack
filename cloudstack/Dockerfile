FROM ubuntu:22.04
# Apache CloudStack management server installed from the official package repo.
# No source build; image builds in ~2 minutes instead of 45.
# External MariaDB required.

ARG DEBIAN_FRONTEND=noninteractive
ARG CS_VERSION=4.22

ENV CLOUDSTACK_HOME=/usr/share/cloudstack-management

# ── repo + package ────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        gnupg curl ca-certificates lsb-release netcat-openbsd default-mysql-client \
    && curl -fsSL http://download.cloudstack.org/release.asc \
        | gpg --dearmor -o /etc/apt/keyrings/cloudstack.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/cloudstack.gpg] \
        http://download.cloudstack.org/ubuntu jammy ${CS_VERSION}" \
        > /etc/apt/sources.list.d/cloudstack.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends cloudstack-management \
    && rm -rf /var/lib/apt/lists/*

# ── entrypoint ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 8080 = management UI/API   8096 = integration API   8250 = agent RPC
EXPOSE 8080 8096 8250

ENTRYPOINT ["/entrypoint.sh"]
