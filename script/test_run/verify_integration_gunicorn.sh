#!/usr/bin/env bash
# Integration test for nginx_gunicorn stack — 출고 conf.d 그대로 기동해 단언한다. 실패 시 exit 1.
set -uo pipefail

DEVSPOON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK_DIR="$DEVSPOON/compose/web_service/nginx_gunicorn"
APP=gunicorn-app

FAILS=0
check() { if eval "$2"; then echo "[PASS] $1"; else echo "[FAIL] $1"; FAILS=$((FAILS+1)); fi; }
code()  { curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H 'Host: localhost' "$@"; }
cid()   { dc ps -q "$1"; }

# 운영 보호: 기존 .env 는 읽지도 고치지도 않는다. .env-example 로 만든 임시 env-file 과 전용 compose 프로젝트명으로 격리한다.
#   (container_name 이 고정이라 같은 스택이 이미 떠 있으면 up 이 이름 충돌로 실패한다 — 운영 컨테이너를 내리지 않는다)
PROJ=devspoon-it-gunicorn
ENVF=$(mktemp)
sed -e 's|^REDIS_PASSWORD=.*|REDIS_PASSWORD=it-redis-pw|' -e 's|^FLOWER_ID=.*|FLOWER_ID=tester|' -e 's|^FLOWER_PWD=.*|FLOWER_PWD=tester-pw|' \
    -e '/^DJANGO_SECRET_KEY=/d' "$STACK_DIR/.env-example" > "$ENVF"
printf 'DJANGO_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" >> "$ENVF"
dc() { docker compose -p "$PROJ" --env-file "$ENVF" "$@"; }

cleanup() {
  (cd "$STACK_DIR" && dc down -v --remove-orphans >/dev/null 2>&1)
  rm -f "$ENVF"
}
trap cleanup EXIT

cd "$STACK_DIR" || exit 1

check "compose up --wait"          'dc up -d --build --wait --wait-timeout 240'
check "HTTP 200 (Host: localhost)" '[ "$(code http://127.0.0.1/)" = 200 ]'
check "/static/.hidden/x.css 403 (중첩 regex 보다 dotfile 차단 우선)" '[ "$(code http://127.0.0.1/static/.hidden/x.css)" = 403 ]'
check "봇 UA 차단 000|444"          '[[ "$(code -A MJ12bot http://127.0.0.1/)" =~ ^(000|444)$ ]]'
check "정상 UA 300회 고속(병렬 50) 503/429/444 없음" '[ "$(seq 300 | xargs -P 50 -I{} curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 -A "Mozilla/5.0 (X11; Linux x86_64)" -H "Host: localhost" http://127.0.0.1/robots.txt | grep -cE "^(503|429|000)$")" = 0 ]'
check "$APP health=healthy"        '[ "$(docker inspect -f "{{.State.Health.Status}}" "$(cid $APP)")" = healthy ]'
check "$APP RestartCount=0"        '[ "$(docker inspect -f "{{.RestartCount}}" "$(cid $APP)")" = 0 ]'
check "webserver RestartCount=0"   '[ "$(docker inspect -f "{{.RestartCount}}" "$(cid webserver)")" = 0 ]'
check "DEBUG off (404 에 URLconf 없음)" '[[ "$(curl -s --max-time 10 -H "Host: localhost" http://127.0.0.1/__debug_probe__/)" != *URLconf* ]]'

echo "FAILS=$FAILS"
[ "$FAILS" -eq 0 ] || exit 1
