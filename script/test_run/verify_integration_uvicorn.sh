#!/usr/bin/env bash
# Integration test for nginx_uvicorn stack — 출고 conf.d 그대로 기동해 단언한다. 실패 시 exit 1.
set -uo pipefail

DEVSPOON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../lib/stability.sh
. "$DEVSPOON/script/lib/stability.sh"
STACK_DIR="$DEVSPOON/compose/web_service/nginx_uvicorn"
APP=uvicorn-app

FAILS=0
check() { if eval "$2"; then echo "[PASS] $1"; else echo "[FAIL] $1"; FAILS=$((FAILS+1)); fi; }
cid()   { dc ps -q "$1"; }

# 운영 보호: 기존 .env 는 읽지도 고치지도 않는다. .env-example 로 만든 임시 env-file 과 전용 compose 프로젝트명으로 격리한다.
#   (container_name 이 고정이라 같은 스택이 이미 떠 있으면 up 이 이름 충돌로 실패한다 — 운영 컨테이너를 내리지 않는다)
PROJ=devspoon-it-uvicorn
ENVF=$(mktemp)
sed -e 's|^REDIS_PASSWORD=.*|REDIS_PASSWORD=it-redis-pw|' -e 's|^FLOWER_ID=.*|FLOWER_ID=tester|' -e 's|^FLOWER_PWD=.*|FLOWER_PWD=tester-pw|' \
    -e '/^DJANGO_SECRET_KEY=/d' "$STACK_DIR/.env-example" > "$ENVF"
printf 'DJANGO_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" >> "$ENVF"
printf 'IMAGE_NAMESPACE=devspoon-it\n' >> "$ENVF"   # 운영 공유 태그(devspoon-*) 대신 테스트 전용 이미지명으로 빌드
dc() { docker compose -p "$PROJ" --env-file "$ENVF" "$@"; }

cleanup() {
  (cd "$STACK_DIR" && dc down -v --remove-orphans >/dev/null 2>&1)
  rm -f "$ENVF"
}
trap cleanup EXIT

cd "$STACK_DIR" || exit 1

check "compose up --wait"          'dc up -d --build --wait --wait-timeout 240'
check "HTTP 준비 대기 (200, 1s 간격 최대 30회)" 'wait_http 200 -H "Host: localhost" http://127.0.0.1/'
check "HTTP 200 (Host: localhost)" 'http_is 200 -H "Host: localhost" http://127.0.0.1/'
check "/static/.hidden/x.css 403 (중첩 regex 보다 dotfile 차단 우선)" 'http_is 403 -H "Host: localhost" http://127.0.0.1/static/.hidden/x.css'
check "봇 UA 차단 000|444"          'http_is "000|444" -A MJ12bot -H "Host: localhost" http://127.0.0.1/'
check "정상 UA 300회 고속(병렬 50) 503/429/444 없음" 'bad=$(seq 300 | xargs -P 50 -I{} curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 -A "Mozilla/5.0 (X11; Linux x86_64)" -H "Host: localhost" http://127.0.0.1/robots.txt | grep -E "^(503|429|000)$" | sort | uniq -c | xargs); [ -z "$bad" ] || echo "    비정상 응답 (건수 코드):$bad"; [ -z "$bad" ]'
check "$APP health=healthy"        '[ "$(docker inspect -f "{{.State.Health.Status}}" "$(cid $APP)")" = healthy ]'
check "$APP·webserver 안정 (${STABLE_WINDOW:-15}s 창: running·RestartCount 0 불변·unhealthy 아님)" 'containers_stable "$(cid $APP)" "$(cid webserver)"'
check "DEBUG off (404 에 URLconf 없음)" '[[ "$(curl -s --max-time 10 -H "Host: localhost" http://127.0.0.1/__debug_probe__/)" != *URLconf* ]]'

dh_host() { sha256sum "$STACK_DIR/ssl/dhparam/dhparam.pem" 2>/dev/null | cut -d' ' -f1; }
dh_ctr()  { dc exec -T webserver sha256sum /etc/nginx/dhparam.pem 2>/dev/null | cut -d' ' -f1; }
# shellcheck disable=SC2034  # check 의 eval 문자열에서 사용
HSHA=$(dh_host)
check "dhparam host 백업 = 컨테이너" '[ -n "$HSHA" ] && [ "$HSHA" = "$(dh_ctr)" ]'
dc down >/dev/null 2>&1
check "compose 재기동 --wait"      'dc up -d --wait --wait-timeout 240 webserver'
check "dhparam 재기동 후 유지"      '[ -n "$HSHA" ] && [ "$HSHA" = "$(dh_ctr)" ]'

echo "FAILS=$FAILS"
[ "$FAILS" -eq 0 ] || exit 1
