#!/usr/bin/env bash
# =============================================================================
# CI 테스트 오케스트레이터
#
# 목적
#   GitHub Actions(push) 에서 호출되어 아래를 순차 검증한다.
#     1) preflight          — 선결 도구/파일/디자인 불변식 점검 (read-only)
#     2) prereq + 로그 디렉토리 생성
#     3) nginx conf 생성기   — 각 config 설정의 적용/반영
#     4) docker-compose 검증 — 모든 스택 compose 문법 + 마운트
#    4b) 저장소 고유 검사   — script/ci/repo-steps.sh (형제 공통 호출 1줄, 내용은 저장소별)
#     5) docker 이미지 빌드  — 모든 Dockerfile
#     6) 회귀(정적 불변식)
#     7) healthcheck 정적    — 5스택 compose healthcheck·depends_on 선언 (정적)
#     8) 스택 매트릭스 동작  — 5스택 직렬 기동: 200·봇 차단·healthy·RestartCount·DEBUG·업로드 403
#     9) 샘플 프로젝트 동작  — django/php
#    10) 스크립트 로그 생성 검증
#
#   - 단계 중 하나라도 실패하면 즉시 중단하고, "어떤 단계에서 / 무슨 에러로"
#     실패했는지 상세 로그(마지막 N 줄)를 Slack + Telegram 으로 전송한다.
#   - 전 단계 통과 시, 시작/종료 시각 + 소요시간과 함께 성공 알림을 전송한다.
#
# 필요한 환경변수(Actions secrets 로 주입; 없으면 해당 채널만 건너뜀)
#   SLACK_WEBHOOK_URL, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
# GitHub Actions 가 자동 제공: GITHUB_REPOSITORY / GITHUB_REF_NAME / GITHUB_SHA ...
# =============================================================================
set -u
export TZ=Asia/Seoul
export DEBIAN_FRONTEND=noninteractive

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || { echo "ROOT 진입 실패"; exit 1; }
REPO_LABEL="devspoon-startup-tizen"
CILOG="$ROOT/log/ci"
mkdir -p "$CILOG"

# django_sample secrets.json 부트스트랩 (ensure_django_secrets)
# shellcheck source=../lib/django_secrets.sh
. "$ROOT/script/lib/django_secrets.sh"
# 알림 본문·업로드 아티팩트 비밀값 마스킹 (mask_secrets, mask_secrets_files)
# shellcheck source=../lib/mask_secrets.sh
. "$ROOT/script/lib/mask_secrets.sh"

START_EPOCH=$(date +%s)
START_HUMAN=$(date '+%Y-%m-%d %H:%M:%S %Z')

FAILED_STEP=""
FAILED_CODE=0
FAILED_LOG=""
PASSED_STEPS=()

# ----------------------------------------------------------------------------
# 알림 헬퍼
# ----------------------------------------------------------------------------
send_slack() {
    local text="$1"
    if [ -z "${SLACK_WEBHOOK_URL:-}" ]; then
        echo "(SLACK_WEBHOOK_URL 미설정 — Slack 알림 건너뜀)"; return 0
    fi
    local payload; payload=$(jq -n --arg t "$text" '{text:$t}')
    if curl -sS --max-time 30 -X POST -H 'Content-type: application/json' \
        --data "$payload" "$SLACK_WEBHOOK_URL" -o /dev/null; then
        echo "(Slack 알림 전송 완료)"
    else
        echo "(Slack 알림 전송 실패)"
    fi
}

send_telegram() {
    local text="$1"
    if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
        echo "(TELEGRAM_* 미설정 — Telegram 알림 건너뜀)"; return 0
    fi
    local payload; payload=$(jq -n --arg c "$TELEGRAM_CHAT_ID" --arg t "$text" \
        '{chat_id:$c, text:$t, disable_web_page_preview:true}')
    if curl -sS --max-time 30 -X POST -H 'Content-type: application/json' \
        --data "$payload" "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" -o /dev/null; then
        echo "(Telegram 알림 전송 완료)"
    else
        echo "(Telegram 알림 전송 실패)"
    fi
}

# ----------------------------------------------------------------------------
# 단계 실행기 — 첫 실패 이후엔 이후 단계를 건너뛴다.
# ----------------------------------------------------------------------------
run_step() {
    local name="$1"; shift
    [ -n "$FAILED_STEP" ] && return 0
    local slug; slug=$(printf '%s' "$name" | tr ' /:' '___')
    local logf="$CILOG/${slug}.log"
    echo "::group::STEP ▶ $name"
    echo "----- STEP ▶ $name -----"
    set -o pipefail
    if "$@" 2>&1 | tee "$logf"; then
        echo "PASS ✓ $name"
        PASSED_STEPS+=("$name")
    else
        local code=${PIPESTATUS[0]}
        FAILED_STEP="$name"; FAILED_CODE=$code; FAILED_LOG="$logf"
        echo "FAIL ✗ $name (exit=$code)"
    fi
    set +o pipefail
    echo "::endgroup::"
}

# ----------------------------------------------------------------------------
# 단계 정의
# ----------------------------------------------------------------------------
step_preflight()  { bash "$ROOT/script/test/preflight.sh"; }
step_prereq()     { bash "$ROOT/script/test_run/s0_prereq.sh"; }
step_conf_gen()   { bash "$ROOT/script/test_run/s1b_nginx_conf_generators.sh"; }
step_compose()    { bash "$ROOT/script/test_run/verify_compose_yml.sh"; }
step_build()      { bash "$ROOT/script/test_run/s2_build.sh"; }
step_regression() { bash "$ROOT/script/test_run/s6_regression.sh"; }
step_healthcheck(){ RUNTIME=0 bash "$ROOT/script/test_run/verify_healthcheck.sh"; }   # 정적 불변식만 — 런타임은 step_stacks
# 스택 5종 직렬(80/443 공유). 하나가 실패해도 나머지를 끝까지 돌려 실패 목록을 남긴다.
step_stacks() { local rc=0 s own; for s in gunicorn uvicorn uwsgi daphne php; do
    echo "### stack: $s ###"; bash "$ROOT/script/test_run/verify_integration_${s}.sh" || { echo "stack FAIL: $s"; rc=1; }; done
    # 컨테이너가 bind mount 된 호스트 소스 트리 소유권을 바꾸지 않아야 한다 (TC-R2-OWN, CL-WP1-08-R2) — 샘플 단계 전에 판정
    own=$(find "$ROOT/www" ! -user "$(id -u)")
    if [ -z "$own" ]; then echo "[PASS] 호스트 소스 트리(www) 소유권 불변"
    else echo "[FAIL] 호스트 소스 트리(www) 비소유 파일 $(grep -c . <<<"$own")"; head -5 <<<"$own"; rc=1; fi
    return $rc; }

step_samples() {
    local rc=0
    command -v uv >/dev/null 2>&1 || { echo "uv 미설치 — 설치 시도"; pip install -q uv || rc=1; }

    echo "### [django_sample] secrets.json 준비 ###"
    # settings.py:26 이 secrets.json 을 강제로 읽는다(추적 해제 파일) — 없을 때만 무작위 키로 생성.
    ensure_django_secrets "$ROOT" || rc=1

    echo "### [django_sample] manage.py check (py3.14 + uv — 런타임과 동일) ###"
    ( cd "$ROOT/www/django_sample" \
        && uv run --python 3.14 --frozen --extra celery python manage.py check ) || { echo "django_sample 실패"; rc=1; }

    # (flask_sample / fastapi_sample 샘플 없음 — django_sample + php_sample 만 검증)

    echo "### [php_sample] php -l ###"
    if command -v php >/dev/null 2>&1; then
        php -l "$ROOT/www/php_sample/index.php" || { echo "php_sample lint 실패"; rc=1; }
    else
        echo "php 미설치 — php_sample lint 건너뜀(WARN)"
    fi
    return $rc
}

step_logcheck() {
    local rc=0
    echo "### 스크립트가 생성한 로그 산출물 확인 ###"
    # s2_build / s0 등이 log/test_run 아래 산출물을 남겼는지 검증
    if [ -d "$ROOT/log/test_run" ] && [ -n "$(ls -A "$ROOT/log/test_run" 2>/dev/null)" ]; then
        echo "  OK : log/test_run 산출물"
        ls -la "$ROOT/log/test_run"
    else
        echo "  FAIL : log/test_run 산출물 없음"; rc=1
    fi
    # 표준 런타임 로그 디렉토리 구조 검증
    local miss=0
    for d in nginx gunicorn uvicorn uwsgi php-fpm supervisor; do
        if [ -d "$ROOT/log/$d" ]; then echo "  OK : log/$d"; else echo "  MISS : log/$d"; miss=$((miss+1)); fi
    done
    [ "$miss" -eq 0 ] || rc=1
    return $rc
}

# ----------------------------------------------------------------------------
# 실행 순서
# ----------------------------------------------------------------------------
run_step "preflight 선결점검"        step_preflight
run_step "prereq+로그디렉토리"       step_prereq
run_step "nginx conf 생성기 반영"    step_conf_gen
run_step "docker-compose 검증"       step_compose
run_step "저장소 고유 검사"          bash "$ROOT/script/ci/repo-steps.sh"
run_step "docker 이미지 빌드"        step_build
run_step "정적 회귀 불변식"          step_regression
run_step "healthcheck 동작검증"      step_healthcheck
run_step "스택 매트릭스 동작검증"    step_stacks
run_step "샘플 프로젝트 동작"        step_samples
run_step "스크립트 로그 생성검증"    step_logcheck

# ----------------------------------------------------------------------------
# 결과 집계 + 알림
# ----------------------------------------------------------------------------
END_EPOCH=$(date +%s)
END_HUMAN=$(date '+%Y-%m-%d %H:%M:%S %Z')
DUR=$((END_EPOCH - START_EPOCH))
DUR_HUMAN="$((DUR/60))분 $((DUR%60))초"

REPO="${GITHUB_REPOSITORY:-$REPO_LABEL}"
BRANCH="${GITHUB_REF_NAME:-local}"
SHA="${GITHUB_SHA:-N/A}"; SHORT="${SHA:0:7}"
ACTOR="${GITHUB_ACTOR:-local}"
RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-}"
PASSED_JOINED=$(IFS=', '; echo "${PASSED_STEPS[*]:-없음}")

# 업로드 아티팩트(log/ci, log/test_run)에도 비밀값 원문이 남지 않도록 로그 파일을 제자리 마스킹
mask_secrets_files "$CILOG" "$ROOT/log/test_run" || echo "WARN: 로그 파일 마스킹 실패 — test.yml 업로드 직전 단계가 재시도한다"

if [ -n "$FAILED_STEP" ]; then
    LOG_TAIL=""
    # 전송 전 비밀값 마스킹 (script/lib/mask_secrets.sh)
    [ -f "$FAILED_LOG" ] && LOG_TAIL=$(tail -n 30 "$FAILED_LOG" | cut -c1-2000 | mask_secrets)
    MSG="❌ [${REPO_LABEL}] CI 테스트 실패
저장소: ${REPO}
브랜치: ${BRANCH} @ ${SHORT}
실행자: ${ACTOR}
시작: ${START_HUMAN}
종료: ${END_HUMAN}
소요: ${DUR_HUMAN}

실패 단계: ${FAILED_STEP} (exit=${FAILED_CODE})
통과 단계: ${PASSED_JOINED}

── 에러 로그(마지막 30줄) ──
${LOG_TAIL}

실행 로그: ${RUN_URL}"
    echo "$MSG"
    send_slack "$MSG"
    send_telegram "$MSG"
    exit "$FAILED_CODE"
fi

MSG="✅ [${REPO_LABEL}] CI 테스트 성공
저장소: ${REPO}
브랜치: ${BRANCH} @ ${SHORT}
실행자: ${ACTOR}
시작: ${START_HUMAN}
종료: ${END_HUMAN}
소요: ${DUR_HUMAN}

통과 단계(${#PASSED_STEPS[@]}개): ${PASSED_JOINED}

실행 로그: ${RUN_URL}"
echo "$MSG"
send_slack "$MSG"
send_telegram "$MSG"
exit 0
