# docker_aime — containerized ARTEMiS All.net server for Initial D THE ARCADE
#
# Self-contained image: ARTEMiS is cloned at a pinned commit *during the build*
# and the overlay patches in ./patches are applied on top. There is no
# host-side checkout to prepare — `docker compose up -d --build` just works.
#
# Why not ARTEMiS's bundled Dockerfile? It pins python:3.9.15-slim-bullseye,
# whose Debian bullseye security pool is gone (mass 404s). We use
# python:3.10-slim-bookworm with the native build deps for pylibmc instead.
FROM python:3.10-slim-bookworm

# Upstream source to build from. Override with --build-arg to track another fork.
ARG ARTEMIS_REPO=https://gitea.tendokyu.moe/Dniel97/artemis.git
ARG ARTEMIS_BRANCH=idac
ARG ARTEMIS_COMMIT=7d4d1e275f6196ef57ab9fc34a7460e370bf13f8

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# git              -> fetch ARTEMiS at build time
# build-essential, pkg-config, libmemcached-dev, libsasl2-dev, libssl-dev,
# zlib1g-dev       -> native wheels in requirements.txt (pylibmc)
# (DB access is pure-python aiomysql/PyMySQL, so no MySQL client headers needed)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git build-essential pkg-config \
      libmemcached-dev libsasl2-dev libssl-dev zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

# --- Fetch ARTEMiS at the pinned commit -------------------------------------
WORKDIR /src
RUN git clone --branch "$ARTEMIS_BRANCH" "$ARTEMIS_REPO" artemis \
 && git -C artemis checkout -f "$ARTEMIS_COMMIT"

# --- Apply our overlay patches ----------------------------------------------
# idac-index.patch: advertise THIS server's hostname (not the hardcoded
#   sega-initiald.net) and widen the season map to 200-339 so SDGT 3.00.00
#   (v300) maps to the Season 3 handlers.
# aimedb.patch: accept a hex/0x-prefixed AimeDB key as well as plain ASCII, and
#   log the raw received packet at debug.
COPY patches /tmp/patches
RUN cd artemis \
 && for p in /tmp/patches/*.patch; do echo "==> applying $(basename "$p")"; git apply "$p"; done \
 && rm -rf /tmp/patches artemis/.git

# --- Python dependencies -----------------------------------------------------
RUN pip3 install -r /src/artemis/requirements.txt

# --- Assemble the runtime image ---------------------------------------------
WORKDIR /app
RUN mkdir -p /app \
 && cp /src/artemis/index.py /src/artemis/dbutils.py /src/artemis/read.py /app/ \
 && cp -r /src/artemis/core /src/artemis/titles /src/artemis/cert /app/ \
 && rm -rf /src

COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && mkdir -p /app/logs

# allnet/title HTTP, billing HTTPS, AimeDB, web UI, IDAC matching/echo/p2p
EXPOSE 80 8443 22345 8080 20000 20001 20002 20003

ENTRYPOINT ["/app/entrypoint.sh"]
