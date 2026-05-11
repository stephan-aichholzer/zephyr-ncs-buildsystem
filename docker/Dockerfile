# syntax=docker/dockerfile:1.7
#
# zephyr_ncs_bundle: self-contained build container for Zephyr / nRF Connect SDK.
# Pinned NCS release at /opt/ncs; Zephyr SDK toolchain(s) at /opt/zephyr-sdk.
# See docker/README.md for usage.

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# ----- OS packages (Zephyr GSG dependencies) -------------------------------
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        git cmake ninja-build gperf ccache dfu-util \
        device-tree-compiler wget \
        python3-dev python3-venv python3-tk python3-pip \
        xz-utils file make gcc gcc-multilib g++-multilib \
        libsdl2-dev libmagic1 \
        ca-certificates curl locales && \
    locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# ----- Corporate TLS-inspection CA certs -----------------------------------
# The network performs SSL inspection on many origins (github.com, jfrog.io,
# ...), re-signing them with a corporate root CA. Drop any *.crt files into
# docker/certs/ and they will be trusted by the system bundle and by tools
# that use certifi (pip, python-requests).
# certs/ always exists (.gitkeep) so this layer is a no-op when empty.
COPY certs/ /usr/local/share/ca-certificates/
RUN update-ca-certificates

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    PIP_CERT=/etc/ssl/certs/ca-certificates.crt \
    GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt

# ----- Non-root user -------------------------------------------------------
# Ubuntu 24.04 ships a default `ubuntu` user at UID 1000 — drop it so we can
# claim UID 1000 for `zephyr` (matches typical Linux dev hosts).
RUN userdel -r ubuntu 2>/dev/null || true && \
    useradd -m -u 1000 -s /bin/bash zephyr && \
    mkdir -p /opt /ccache /workdir /artifacts && \
    chown zephyr:zephyr /opt /ccache /workdir /artifacts

USER zephyr
WORKDIR /home/zephyr

# ----- Python venv + west --------------------------------------------------
ARG WEST_VERSION=1.2.0
RUN --mount=type=cache,target=/home/zephyr/.cache/pip,uid=1000,gid=1000 \
    python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install "west==${WEST_VERSION}"

ENV PATH=/opt/venv/bin:$PATH

# ----- NCS workspace (the expensive layer) ---------------------------------
# Placed late so edits above (apt, user, west) don't bust this cache.
ARG NCS_REVISION=v3.3.0
RUN --mount=type=cache,target=/home/zephyr/.cache/pip,uid=1000,gid=1000 \
    west init -m https://github.com/nrfconnect/sdk-nrf --mr "${NCS_REVISION}" /opt/ncs && \
    cd /opt/ncs && \
    west update --narrow -o=--depth=1 && \
    west zephyr-export && \
    west packages pip --install

# ----- Zephyr SDK toolchain ------------------------------------------------
# Pinned to the SDK_VERSION that NCS v3.3.0 expects. Override via
# --build-arg ZSDK_VERSION=<x.y.z> when bumping NCS to a release that
# requires a different SDK. Leaving the arg empty falls back to whatever
# /opt/ncs/zephyr/SDK_VERSION reports.
ARG ZSDK_VERSION=0.17.4
ARG INCLUDE_VPR=0
RUN cd /opt/ncs && \
    VER_ARG=""; [ -n "${ZSDK_VERSION}" ] && VER_ARG="--version ${ZSDK_VERSION}"; \
    VPR_ARG=""; [ "${INCLUDE_VPR}" = "1" ] && VPR_ARG="-t riscv64-zephyr-elf"; \
    west sdk install ${VER_ARG} -t arm-zephyr-eabi ${VPR_ARG} -b /opt && \
    ln -sfn /opt/zephyr-sdk-* /opt/zephyr-sdk

ENV ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk \
    ZEPHYR_TOOLCHAIN_VARIANT=zephyr \
    ZEPHYR_BASE=/opt/ncs/zephyr \
    CCACHE_DIR=/ccache \
    CCACHE_MAXSIZE=5G

# ----- Developer / diagnostic tools ----------------------------------------
# Placed after the NCS+SDK layers so iterating on this list does not bust the
# expensive workspace cache.
USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        vim less nano \
        build-essential \
        iputils-ping traceroute mtr-tiny \
        diffutils xxd \
        valgrind strace gdb \
        jq tree \
        unzip zip \
        iproute2 dnsutils netcat-openbsd openssh-client \
        tmux htop

# ----- JFrog CLI -----------------------------------------------------------
ARG JFROG_VERSION=2.103.0
RUN curl -fsSL -o /usr/local/bin/jf \
        "https://releases.jfrog.io/artifactory/jfrog-cli/v2-jf/${JFROG_VERSION}/jfrog-cli-linux-amd64/jf" && \
    chmod +x /usr/local/bin/jf && \
    /usr/local/bin/jf --version

# ----- Entrypoint ----------------------------------------------------------
COPY --chmod=0755 entrypoint.sh /usr/local/bin/zephyr-entrypoint.sh

USER zephyr
WORKDIR /workdir
ENTRYPOINT ["/usr/local/bin/zephyr-entrypoint.sh"]
CMD ["build"]
