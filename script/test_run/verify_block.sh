#!/usr/bin/env bash
# Direct verification of blocking with stderr suppressed
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
echo "--- evil Host ---"
code=$(curl -sS -o /dev/null -w "%{http_code}" -H "Host: evil.com" http://127.0.0.1/ 2>/dev/null)
echo "code=[$code]"
echo "--- MJ12bot ---"
code=$(curl -sS -A "MJ12bot" -o /dev/null -w "%{http_code}" -H "Host: localhost" http://127.0.0.1/ 2>/dev/null)
echo "code=[$code]"
echo "--- celery log dir ---"
ls -la "$ROOT/log/gunicorn/celery/" 2>&1 | head -20
echo "--- celery container log out ---"
docker exec celery-app ls -la /log/gunicorn/celery/ 2>&1 | head -20
echo "--- celery process check ---"
docker exec celery-app ps auxf 2>&1 | head -20
