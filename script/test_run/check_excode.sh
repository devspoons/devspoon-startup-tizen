#!/usr/bin/env bash
# Check exit code of nginx_http_conf.sh on invalid input across all stacks
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
for stack in gunicorn uvicorn uwsgi php; do
  cd "$ROOT/config/web-server/nginx/$stack" || { echo "$stack: missing dir"; continue; }
  ./nginx_http_conf.sh -w x -p 99999 -d X -a Y -s Z >/dev/null 2>&1
  rc=$?
  echo "$stack invalid-input exit_code = $rc"
done

# also test the simulation
cd "$ROOT"
n=99999
(
  set -euo pipefail
  (( 10#$n >= 1 && 10#$n <= 65535 )) || { echo "range error" >&2; exit 2; }
)
echo "simulation_subshell_rc = $?"
