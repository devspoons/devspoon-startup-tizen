#!/usr/bin/env bash
# Integration test for nginx_daphne stack — 출고 conf.d 그대로 기동해 단언한다. 실패 시 exit 1.
set -uo pipefail

DEVSPOON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK_DIR="$DEVSPOON/compose/web_service/nginx_daphne"
APP=daphne-app

FAILS=0
check() { if eval "$2"; then echo "[PASS] $1"; else echo "[FAIL] $1"; FAILS=$((FAILS+1)); fi; }
code()  { curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H 'Host: localhost' "$@"; }
cid()   { docker compose ps -q "$1"; }

cleanup() { cd "$STACK_DIR" && docker compose down -v --remove-orphans >/dev/null 2>&1 || true; }
trap cleanup EXIT

cd "$STACK_DIR" || exit 1
[ -f .env ] || cp .env-example .env
sed -i 's|^REDIS_PASSWORD=.*|REDIS_PASSWORD=daphne-test-redis-pw|; s|^FLOWER_ID=.*|FLOWER_ID=tester|; s|^FLOWER_PWD=.*|FLOWER_PWD=tester-pw|' .env
# shellcheck source=../lib/django_secrets.sh
. "$DEVSPOON/script/lib/django_secrets.sh"
ensure_django_secrets "$DEVSPOON" || exit 1

check "compose up --wait"          'docker compose up -d --build --wait --wait-timeout 240'
check "HTTP 200 (Host: localhost)" '[ "$(code http://127.0.0.1/)" = 200 ]'
check "봇 UA 차단 000|444"          '[[ "$(code -A MJ12bot http://127.0.0.1/)" =~ ^(000|444)$ ]]'
check "정상 UA 300회 고속(병렬 50) 503/429/444 없음" '[ "$(seq 300 | xargs -P 50 -I{} curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 -A "Mozilla/5.0 (X11; Linux x86_64)" -H "Host: localhost" http://127.0.0.1/robots.txt | grep -cE "^(503|429|000)$")" = 0 ]'
check "$APP health=healthy"        '[ "$(docker inspect -f "{{.State.Health.Status}}" "$(cid $APP)")" = healthy ]'
check "$APP RestartCount=0"        '[ "$(docker inspect -f "{{.RestartCount}}" "$(cid $APP)")" = 0 ]'
check "webserver RestartCount=0"   '[ "$(docker inspect -f "{{.RestartCount}}" "$(cid webserver)")" = 0 ]'
check "DEBUG off (404 에 URLconf 없음)" '[[ "$(curl -s --max-time 10 -H "Host: localhost" http://127.0.0.1/__debug_probe__/)" != *URLconf* ]]'

dh_host() { sha256sum "$STACK_DIR/ssl/dhparam/dhparam.pem" 2>/dev/null | cut -d' ' -f1; }
dh_ctr()  { docker compose exec -T webserver sha256sum /etc/nginx/dhparam.pem 2>/dev/null | cut -d' ' -f1; }
# shellcheck disable=SC2034  # check 의 eval 문자열에서 사용
HSHA=$(dh_host)
check "dhparam host 백업 = 컨테이너" '[ -n "$HSHA" ] && [ "$HSHA" = "$(dh_ctr)" ]'

echo "FAILS=$FAILS"
[ "$FAILS" -eq 0 ] || exit 1
