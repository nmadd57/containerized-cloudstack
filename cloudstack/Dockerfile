FROM ubuntu:24.04
# Apache CloudStack management server installed from the official package repo.
# No source build; image builds in ~2 minutes instead of 45.
# External MariaDB required.

ARG DEBIAN_FRONTEND=noninteractive
ARG CS_VERSION=4.22
ARG OIDC_PLUGIN_REPO=nmadd57/cloudstack-oidc-plugin

ENV CLOUDSTACK_HOME=/usr/share/cloudstack-management

# ── repo + package ────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        gnupg curl ca-certificates lsb-release netcat-openbsd default-mysql-client \
    && curl -fsSL http://download.cloudstack.org/release.asc \
        | gpg --dearmor -o /etc/apt/keyrings/cloudstack.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/cloudstack.gpg] \
        http://download.cloudstack.org/ubuntu noble ${CS_VERSION}" \
        > /etc/apt/sources.list.d/cloudstack.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends cloudstack-management \
    && rm -rf /var/lib/apt/lists/*

# ── generic OIDC auth plugin ──────────────────────────────────────────────────
# Adds an "oidc" provider alongside the built-in google/github ones. It's a
# plain jar dropped on the management server's classpath: CloudStack's Spring
# module loader merges every META-INF/cloudstack/oauth2/*.xml it finds into a
# single module context, so no source rebuild of CloudStack is needed.
# releases/latest/download is GitHub's stable redirect to whichever release is
# currently flagged "latest" - it follows that flag rather than a tag name, so
# it keeps working even though each build is tagged uniquely (see the plugin's
# own workflow for why: a moving tag breaks any clone that already fetched it).
RUN curl -fsSL \
        "https://github.com/${OIDC_PLUGIN_REPO}/releases/latest/download/cloudstack-oidc-plugin.jar" \
        -o "${CLOUDSTACK_HOME}/lib/cloudstack-oidc-plugin.jar"

# ── entrypoint ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 8080 = management UI/API   8096 = integration API   8250 = agent RPC
EXPOSE 8080 8096 8250

ENTRYPOINT ["/entrypoint.sh"]
