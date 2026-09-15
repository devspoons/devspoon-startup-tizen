#!/usr/bin/env bash
# =============================================================================
# verify_healthcheck.sh — app/webserver/redis healthcheck 통합 검증
#
# 목적
#   1) 모든 stack 의 docker-compose.yml 에 app/webserver healthcheck + depends_on
#      service_healthy 가 선언되어 있는지 정적 검증.
#   2) 한 스택을 실제 기동하여 healthcheck 가 "starting → healthy" 로 전환되는지
#      관찰 (default: nginx_php — Python 빌드 불필요로 빠름).
#
# 사용
#   ./verify_healthcheck.sh                  # static only + nginx_php 런타임 검증
#   STACK=nginx_gunicorn ./verify_healthcheck.sh
#   RUNTIME=0 ./verify_healthcheck.sh        # 정적 검증만
#
# 참고
#   - 본 스크립트는 ROOT 를 호출 위치 기준으로 추정하므로 어디서나 동작.
#   - WSL 호스트라면 사전에 README §11 가이드대로 redis.conf 권한이 0644 인지
#     확인 (`ls -l compose/web_service/*/redis/conf/redis.conf`).
# =============================================================================
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../lib/stability.sh
. "$ROOT/script/lib/stability.sh"
STACK="${STACK:-nginx_php}"
RUNTIME="${RUNTIME:-1}"

PASS=0
FAIL=0
pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1 -- $2"; FAIL=$((FAIL+1)); }

# ---------------------------------------------------------------------------
# Section A — 정적: 모든 stack 의 compose YAML 안에 healthcheck/depends_on 존재
# ---------------------------------------------------------------------------
echo "=============================================================="
echo " A. Static check: healthcheck + depends_on across all stacks"
echo "=============================================================="

declare -A APP_MAP=(
    [nginx_gunicorn]="gunicorn-app:8000"
    [nginx_uvicorn]="uvicorn-app:8000"
    [nginx_uwsgi]="uwsgi-app:8000"
    [nginx_daphne]="daphne-app:8000"
    [nginx_php]="php-app:9000"
)

for stack in "${!APP_MAP[@]}"; do
    spec="${APP_MAP[$stack]}"
    app="${spec%%:*}"
    port="${spec##*:}"
    yml="$ROOT/compose/web_service/$stack/docker-compose.yml"

    echo
    echo "--- $stack ($app : $port) ---"

    if [ ! -f "$yml" ]; then
        fail "$stack" "compose file not found"
        continue
    fi

    # app service 에 healthcheck 정의?
    # grep multi-line 약식: app service 다음의 50라인 안에 healthcheck + /dev/tcp/...port 가 함께 나오는지
    if awk -v svc="^  $app:" '
        $0 ~ svc {found=1; next}
        found && /^  [a-z]/ {found=0}
        found {print}
    ' "$yml" | grep -qE "/dev/tcp/127\.0\.0\.1/$port"; then
        pass "$stack: $app healthcheck (port $port)"
    else
        fail "$stack: $app healthcheck (port $port)" "missing /dev/tcp/127.0.0.1/$port probe"
    fi

    # webserver 의 depends_on 에 app: service_healthy?
    if awk '
        /^  webserver:/ {found=1; next}
        found && /^  [a-z]/ {found=0}
        found {print}
    ' "$yml" | awk -v app="$app:" '
        $1 == "depends_on:" {in_dep=1; next}
        in_dep && $0 !~ /^[ ]{6,}/ && $0 !~ /^$/ && $0 !~ /condition/ && $1 != app {in_svc=0}
        in_dep && $1 == app {in_svc=1; next}
        in_svc && /condition:[ ]*service_healthy/ {print "MATCH"; exit}
    ' | grep -q MATCH; then
        pass "$stack: webserver depends_on $app service_healthy"
    else
        fail "$stack: webserver depends_on $app service_healthy" "missing or wrong condition"
    fi
done

echo
echo "=== Static summary: $PASS passed, $FAIL failed ==="
STATIC_FAIL=$FAIL

# ---------------------------------------------------------------------------
# Section B — Runtime: 1개 stack 을 띄워 healthy 전환 확인
# ---------------------------------------------------------------------------
if [ "$RUNTIME" != "1" ]; then
    echo
    echo "(skipping runtime check — RUNTIME=$RUNTIME)"
    exit $STATIC_FAIL
fi

echo
echo "=============================================================="
echo " B. Runtime: bring up stack '$STACK' and observe healthy"
echo "=============================================================="

cd "$ROOT/compose/web_service/$STACK" || { echo "FAIL: cd"; exit 1; }

# 운영 보호: 기존 .env 는 읽지도 고치지도 않는다 — 임시 env-file + 전용 compose 프로젝트명으로 격리
PROJ="devspoon-hc-${STACK//./-}"   # compose 프로젝트명은 소문자·숫자·-·_ 만 허용 (nginx_php 의 . 치환)
ENVF=$(mktemp)
sed -e 's|^REDIS_PASSWORD=.*|REDIS_PASSWORD=test-redis-pw|; s|^FLOWER_ID=.*|FLOWER_ID=test|; s|^FLOWER_PWD=.*|FLOWER_PWD=test-pw|' \
    -e '/^DJANGO_SECRET_KEY=/d' .env-example > "$ENVF"
printf 'DJANGO_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" >> "$ENVF"
printf 'IMAGE_NAMESPACE=devspoon-it\n' >> "$ENVF"   # 운영 공유 태그(devspoon-*) 대신 테스트 전용 이미지명으로 빌드
dc() { docker compose -p "$PROJ" --env-file "$ENVF" "$@"; }
# 어느 지점에서 끝나도(B.0 exit 포함) 테스트 프로젝트를 정리한다 (RV1-S-06)
trap 'dc --profile redis --profile celery down -v --remove-orphans >/dev/null 2>&1; rm -f "$ENVF"' EXIT

echo
echo "--- compose down -v (cleanup) ---"
dc --profile redis --profile celery down -v 2>&1 | tail -5

echo
echo "--- compose up -d --build ---"
if ! dc up -d --build; then
    echo "  compose up 실패 — 1회 재시도"; sleep 5
    dc up -d --build || { fail "B.0 compose up" "exit≠0 (재시도 포함)"; exit 1; }
fi

# Wait up to 120s for app healthcheck to flip to healthy
echo
echo "--- Polling: app health status (up to 120s) ---"
app_service=$(echo "${APP_MAP[$STACK]}" | cut -d: -f1)
deadline=$(( $(date +%s) + 120 ))
app_healthy=0
while [ "$(date +%s)" -lt "$deadline" ]; do
    state=$(dc ps --format '{{.Service}} {{.Status}}' 2>/dev/null | grep "^$app_service " | head -1)
    echo "  $(date +%H:%M:%S) | $state"
    if echo "$state" | grep -q "(healthy)"; then
        app_healthy=1
        break
    fi
    sleep 5
done

if [ $app_healthy -eq 1 ]; then
    pass "B.1 $app_service reached (healthy)"
else
    fail "B.1 $app_service reached (healthy)" "did not become healthy within 120s"
fi

echo
echo "--- compose ps (final) ---"
dc ps

# 순간 관측("Up"·running 0)은 기동 직후 재시작 루프도 통과시킨다 — 안정화 창 전후 두 번 관측해 판정 (TC-F9-1)
echo
echo "--- app·webserver 안정화 창 ${STABLE_WINDOW:-15}s ---"
if containers_stable "$(dc ps -q "$app_service")" "$(dc ps -q webserver)"; then
    pass "B.2 $app_service·webserver 안정 (running·RestartCount 0 불변·unhealthy 아님)"
else
    fail "B.2 $app_service·webserver 안정" "재시작 또는 비running (위 unstable 로그)"
fi

# redis healthy 검증
redis_status=$(dc ps --format '{{.Service}} {{.Status}}' 2>/dev/null | grep "^redis " | head -1)
if [ -n "$redis_status" ]; then
    if echo "$redis_status" | grep -q "(healthy)"; then
        pass "B.3 redis (healthy)"
    else
        # PHP 스택은 redis 가 profile 뒤에 있으므로 미기동 = 정상
        echo "  (redis status: $redis_status)"
    fi
fi

echo
echo "--- Tear down ---"
dc --profile redis --profile celery down -v 2>&1 | tail -5

echo
echo "=============================================================="
echo " Final: STATIC_FAIL=$STATIC_FAIL RUNTIME_PASS=$PASS RUNTIME_FAIL=$FAIL"
echo "=============================================================="

# 종합 exit code
[ "$STATIC_FAIL" -eq 0 ] && [ "$FAIL" -eq 0 ]
