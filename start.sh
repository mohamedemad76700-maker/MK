#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
command -v node >/dev/null 2>&1 || { echo 'Node.js 22 or newer is required.'; exit 1; }
node_major="$(node -p 'Number(process.versions.node.split(".")[0])')"
if (( node_major < 22 )); then
  echo "Node.js 22 or newer is required; found $(node --version)."
  exit 1
fi

if [ ! -f .env ]; then
  node video_engine_backend/scripts/init-env.cjs
  echo '[SETUP] Created .env with a one-time administrator password. Configure PostgreSQL, Redis, and the admin login, then run this script again.'
  exit 0
fi

node video_engine_backend/scripts/init-env.cjs
if [ ! -d video_engine_backend/node_modules ]; then (cd video_engine_backend && npm install); fi
(cd video_engine_backend && npm run build)
echo "[*] Starting the backend at http://127.0.0.1:8080"
exec node --env-file=.env video_engine_backend/dist/main.js
