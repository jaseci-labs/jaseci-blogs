#!/usr/bin/env bash
# Local dev launcher for the Jac app: loads .env (so the submission portal's
# GH_OAUTH_* / SUBMIT_SESSION_SECRET are in the environment) then starts the
# server. Usage:  ./scripts/dev.sh   (pass extra flags through, e.g. --scale)
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .env ]; then
  set -a            # export everything defined while sourcing
  # shellcheck disable=SC1091
  source .env
  set +a
  echo "Loaded .env ($(grep -cE '^[A-Za-z_]+=' .env) vars)"
else
  echo "No .env found — /submit and /reviewer will report 'not configured'."
fi

# Prefer the project venv's jac (has the scale/client plugins) if present,
# else fall back to a global jac.
if [ -x .jac/venv/bin/jac ]; then
  JAC=.jac/venv/bin/jac
else
  JAC=jac
fi

exec "$JAC" start main.jac "$@"
