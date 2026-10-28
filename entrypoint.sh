#!/bin/bash
# docker_aime entrypoint: initialise the schema once, then run ARTEMiS.
set -e

echo "==> ARTEMiS starting (config dir: ${ARTEMIS_CFG_DIR:-config})"

# Create/upgrade the database schema. Safe to run on every start: 'create'
# establishes a fresh schema, 'upgrade' applies any migrations on top.
if [ -z "${SKIP_DB_INIT:-}" ]; then
  echo "==> initialising database schema"
  python3 dbutils.py create  || echo "   (create returned non-zero — assuming schema exists)"
  python3 dbutils.py upgrade || echo "   (upgrade returned non-zero — continuing)"
fi

echo "==> launching server"
exec python3 index.py "$@"
