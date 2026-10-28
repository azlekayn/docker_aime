#!/usr/bin/env bash
# Optional helper: create .env from the example and (re)inject IDAC_HOSTNAME /
# AIMEDB_KEY into config/*.yaml so the stack is correct whether or not the
# image honours CFG_* environment overrides.
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  cp .env.example .env
  cat <<'EOF'
Created .env

  1. Edit IDAC_HOSTNAME -> the IP/hostname game clients use to reach this box
                           (NOT 127.0.0.1; the game rejects loopback)
  2. Edit AIMEDB_KEY     -> your AimeDB key (default "Copyright(C)SEGA")
  3. Re-run:  ./setup.sh
EOF
  exit 0
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

: "${IDAC_HOSTNAME:?please set IDAC_HOSTNAME in .env}"
AIMEDB_KEY="${AIMEDB_KEY:-}"

# The image clones ARTEMiS at build time, so there is no source to prepare here.

echo "==> writing hostname=${IDAC_HOSTNAME} into configs"
sed -i -e "s|^\(  hostname: \).*|\1\"${IDAC_HOSTNAME}\"|" config/core.yaml
sed -i -e "s|^\(  matching_host: \).*|\1\"${IDAC_HOSTNAME}\"|" config/idac.yaml
if [ -n "$AIMEDB_KEY" ]; then
  sed -i -e "s|^\(  key: \).*|\1\"${AIMEDB_KEY}\"|" config/core.yaml
fi

echo "==> setup complete"
echo "    next:  docker compose up -d --build"
