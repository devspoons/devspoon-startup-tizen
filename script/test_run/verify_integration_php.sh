#!/usr/bin/env bash
# Integration test for nginx_php stack — 출고 conf.d 그대로 기동해 단언한다. 실패 시 exit 1.
set -uo pipefail

DEVSPOON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK_DIR="$DEVSPOON/compose/web_service/nginx_php"
APP=php-app

FAILS=0
check() { if eval "$2"; then echo "[PASS] $1"; else echo "[FAIL] $1"; FAILS=$((FAILS+1)); fi; }
code()  { curl -s -o /dev/null -w '%{http_code}' --max-time 10 -H 'Host: localhost' "$@"; }
cid()   { docker compose ps -q "$1"; }
UP="$DEVSPOON/www/php_sample/uploads"

cleanup() {
  cd "$STACK_DIR" && docker compose down -v --remove-orphans >/dev/null 2>&1 || true
  rm -f "$UP/x.php" "$UP/x.phtml"; rmdir "$UP" 2>/dev/null || true
}
trap cleanup EXIT

cd "$STACK_DIR" || exit 1
[ -f .env ] || cp .env-example .env
sed -i 's|^REDIS_PASSWORD=.*|REDIS_PASSWORD=php-test-redis-pw|; s|^FLOWER_ID=.*|FLOWER_ID=tester|; s|^FLOWER_PWD=.*|FLOWER_PWD=tester-pw|' .env
mkdir -p "$UP"; printf '<?php echo "EXECUTED";' > "$UP/x.php"; cp "$UP/x.php" "$UP/x.phtml"

check "compose up --wait"          'docker compose up -d --build --wait --wait-timeout 240'
check "HTTP 200 (Host: localhost)" '[ "$(code http://127.0.0.1/)" = 200 ]'
check "봇 UA 차단 000|444"          '[[ "$(code -A MJ12bot http://127.0.0.1/)" =~ ^(000|444)$ ]]'
check "정상 UA 300회 고속(병렬 50) 503/429/444 없음" '[ "$(seq 300 | xargs -P 50 -I{} curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 -A "Mozilla/5.0 (X11; Linux x86_64)" -H "Host: localhost" http://127.0.0.1/robots.txt | grep -cE "^(503|429|000)$")" = 0 ]'
check "$APP health=healthy"        '[ "$(docker inspect -f "{{.State.Health.Status}}" "$(cid $APP)")" = healthy ]'
check "$APP RestartCount=0"        '[ "$(docker inspect -f "{{.RestartCount}}" "$(cid $APP)")" = 0 ]'
check "webserver RestartCount=0"   '[ "$(docker inspect -f "{{.RestartCount}}" "$(cid webserver)")" = 0 ]'
check "/index.php 200"          '[ "$(code http://127.0.0.1/index.php)" = 200 ]'
check "/uploads/x.php 403"      '[ "$(code http://127.0.0.1/uploads/x.php)" = 403 ]'
check "/uploads/x.php/foo 403"  '[ "$(code http://127.0.0.1/uploads/x.php/foo)" = 403 ]'
check "/uploads/x.phtml 403"    '[ "$(code http://127.0.0.1/uploads/x.phtml)" = 403 ]'

# php 설정 실로드 — www.conf·php.ini 단일 파일 마운트(D-PHP)가 공식 이미지 경로에서 읽히는지 (SW-06)
check "php-fpm pool [www] 로드"    'docker compose exec -T $APP php-fpm -tt 2>&1 | grep -q "\[www\]"'
check "php.ini 로드 경로"          'docker compose exec -T $APP php --ini | grep -q "Loaded Configuration File:.*/usr/local/etc/php/php.ini"'
check "expose_php Off"            'docker compose exec -T $APP php -i | grep -q "^expose_php => Off"'

echo "FAILS=$FAILS"
[ "$FAILS" -eq 0 ] || exit 1
