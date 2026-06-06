FROM ubuntu:22.04
# Apache CloudStack management server, built from the main branch.
# External MariaDB is required; this image does not bundle a database.

ARG DEBIAN_FRONTEND=noninteractive
ARG CLOUDSTACK_BRANCH=main
ARG MAVEN_OPTS="-Xmx3g -XX:MaxMetaspaceSize=512m"

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    PATH="/usr/lib/jvm/java-17-openjdk-amd64/bin:$PATH" \
    MAVEN_OPTS="-Xmx3g -XX:MaxMetaspaceSize=512m" \
    CLOUDSTACK_HOME=/cloudstack

# ── build + runtime deps ──────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-17-jdk \
        maven \
        git \
        python3 python3-pip python3-dev python3-setuptools \
        python3-mysqldb \
        nodejs npm \
        default-mysql-client \
        netcat-openbsd \
        supervisor \
        wget curl \
    && rm -rf /var/lib/apt/lists/*

# ── clone & build ─────────────────────────────────────────────────────────────
# shallow clone; build with the same flags as upstream to avoid needing
# proprietary VMware SDK jars (vmware-vim25/pbm are not in public repos).
# The simulator profile replaces VMware with mock implementations at compile
# time; jetty:run at runtime is started WITHOUT -Dsimulator so the server
# behaves as a real management plane.
RUN git clone --depth=1 --branch "${CLOUDSTACK_BRANCH}" \
        https://github.com/apache/cloudstack.git "${CLOUDSTACK_HOME}"

RUN cd "${CLOUDSTACK_HOME}" \
    && mvn -T 4 \
        -Dnoredist \
        -Dsimulator \
        -P developer,systemvm \
        -DskipTests \
        -q \
        install

# ── supervisord config ────────────────────────────────────────────────────────
COPY supervisord.conf /etc/supervisor/conf.d/cloudstack.conf

# ── entrypoint ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR "${CLOUDSTACK_HOME}"

# 8080 = management UI/API   8096 = integration API (admin, keep firewalled)
# 8250 = agent RPC (needed if KVM agents will register)
EXPOSE 8080 8096 8250

ENTRYPOINT ["/entrypoint.sh"]
