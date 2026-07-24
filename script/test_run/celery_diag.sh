#!/usr/bin/env bash
# Celery 진단. 사용법: celery_diag.sh [stack_dir]  (기본 nginx_gunicorn)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK_DIR="${1:-nginx_gunicorn}"
echo "--- compose ps ---"
cd "$ROOT/compose/web_service/$STACK_DIR" || { echo "FAIL cd $STACK_DIR"; exit 1; }
docker compose --profile celery --profile redis ps
echo "--- celery logs (last 60) ---"
docker compose logs --tail=60 celery 2>&1
echo "--- celery-beat logs ---"
docker compose logs --tail=40 celery-beat 2>&1
