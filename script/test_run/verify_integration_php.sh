#!/usr/bin/env bash
# Integration test for nginx_php stack — 출고 conf.d 그대로 기동해 단언한다. 실패 시 exit 1.
set -uo pipefail

DEVSPOON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/stability.sh
. "$DEVSPOON/script/lib/stability.sh"
STACK_DIR="$DEVSPOON/compose/web_service/nginx_php"
APP=php-app

FAILS=0
check() { if eval "$2"; then echo "[PASS] $1"; else echo "[FAIL] $1"; FAILS=$((FAILS+1)); fi; }
cid()   { dc ps -q "$1"; }
UP="$DEVSPOON/www/php_sample/uploads"

# 운영 보호: 기존 .env 는 읽지도 고치지도 않는다. .env-example 로 만든 임시 env-file 과 전용 compose 프로젝트명으로 격리한다.
#   (container_name 이 고정이라 같은 스택이 이미 떠 있으면 up 이 이름 충돌로 실패한다 — 운영 컨테이너를 내리지 않는다)
PROJ=devspoon-it-php
ENVF=$(mktemp)
sed -e 's|^REDIS_PASSWORD=.*|REDIS_PASSWORD=it-redis-pw|' -e 's|^FLOWER_ID=.*|FLOWER_ID=tester|' -e 's|^FLOWER_PWD=.*|FLOWER_PWD=tester-pw|' \
    -e '/^DJANGO_SECRET_KEY=/d' "$STACK_DIR/.env-example" > "$ENVF"
printf 'DJANGO_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" >> "$ENVF"
printf 'IMAGE_NAMESPACE=devspoon-it\n' >> "$ENVF"   # 운영 공유 태그(devspoon-*) 대신 테스트 전용 이미지명으로 빌드
dc() { docker compose -p "$PROJ" --env-file "$ENVF" "$@"; }

cleanup() {
  (cd "$STACK_DIR" && dc down -v --remove-orphans >/dev/null 2>&1)
  rm -f "$ENVF"
  rm -f "$UP/x.php" "$UP/x.phtml"; rmdir "$UP" 2>/dev/null || true
}
trap cleanup EXIT

cd "$STACK_DIR" || exit 1
mkdir -p "$UP"; printf '<?php echo "EXECUTED";' > "$UP/x.php"; cp "$UP/x.php" "$UP/x.phtml"

check "compose up --wait"          'dc up -d --build --wait --wait-timeout 240'
check "HTTP 준비 대기 (200, 1s 간격 최대 30회)" 'wait_http 200 -H "Host: localhost" http://127.0.0.1/'
check "HTTP 200 (Host: localhost)" 'http_is 200 -H "Host: localhost" http://127.0.0.1/'
check "/.hidden/x.js 403 (dotfile 차단 우선)"      'http_is 403 -H "Host: localhost" http://127.0.0.1/.hidden/x.js'
check "/uploads/x.php/y.png 403 (업로드 차단 우선)" 'http_is 403 -H "Host: localhost" http://127.0.0.1/uploads/x.php/y.png'
check "봇 UA 차단 000|444"          'http_is "000|444" -A MJ12bot -H "Host: localhost" http://127.0.0.1/'
check "정상 UA 300회 고속(병렬 50) 503/429/444 없음" 'bad=$(seq 300 | xargs -P 50 -I{} curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 -A "Mozilla/5.0 (X11; Linux x86_64)" -H "Host: localhost" http://127.0.0.1/robots.txt | grep -E "^(503|429|000)$" | sort | uniq -c | xargs); [ -z "$bad" ] || echo "    비정상 응답 (건수 코드):$bad"; [ -z "$bad" ]'
check "$APP health=healthy"        '[ "$(docker inspect -f "{{.State.Health.Status}}" "$(cid $APP)")" = healthy ]'
check "$APP·webserver 안정 (${STABLE_WINDOW:-15}s 창: running·RestartCount 0 불변·unhealthy 아님)" 'containers_stable "$(cid $APP)" "$(cid webserver)"'
check "/index.php 200"          'http_is 200 -H "Host: localhost" http://127.0.0.1/index.php'
check "/uploads/x.php 403"      'http_is 403 -H "Host: localhost" http://127.0.0.1/uploads/x.php'
check "/uploads/x.php/foo 403"  'http_is 403 -H "Host: localhost" http://127.0.0.1/uploads/x.php/foo'
check "/uploads/x.phtml 403"    'http_is 403 -H "Host: localhost" http://127.0.0.1/uploads/x.phtml'

# php 설정 실로드 — www.conf·php.ini 단일 파일 마운트(D-PHP)가 공식 이미지 경로에서 읽히는지 (SW-06)
check "php-fpm pool [www] 로드"    'out=$(dc exec -T $APP php-fpm -tt 2>&1) && grep -q "\[www\]" <<<"$out"'
check "php.ini 로드 경로"          'out=$(dc exec -T $APP php --ini) && grep -q "Loaded Configuration File:.*/usr/local/etc/php/php.ini" <<<"$out"'
check "expose_php Off"            'out=$(dc exec -T $APP php -i) && grep -q "^expose_php => Off" <<<"$out"'

echo "FAILS=$FAILS"
[ "$FAILS" -eq 0 ] || exit 1
