#!/usr/bin/env bash
# =============================================================================
# devspoon-startup 계열 CI 테스트 오케스트레이터 (제네릭 / 저장소 구조 자동 탐지)
#
# 대상: devspoon-startup-web / devspoon-startup-tizen / devspoon-startup-cloud-tizen
#       (compose/web_service, docker/*, config/*, www/* 구조 공통)
#
# 검증 항목 (GitHub Actions push 시 자동 실행, 테스트 전용 — 배포 없음)
#   1) 필수 도구 확인
#   2) 런타임 로그 디렉토리 생성 + CI 용 .env 준비
#   3) docker-compose 적용/반영 검증  — web_service / master_service 스택 config
#   4) 셸 스크립트 문법 검증          — script/**, config/** 의 *.sh (대화형 안전)
#   5) docker 이미지 빌드             — docker/** 의 모든 Dockerfile
#   6) config 설정 반영 검증          — nginx/app 서버 설정 파일 존재 + 생성기 문법
#   7) 스크립트 로그 생성 검증        — logrotate 정의 + 로그 디렉토리
#   8) 샘플 프로젝트 동작             — django manage.py check / php -l
#
#   - 임의 단계 실패 시 즉시 중단하고 "어떤 단계 / 무슨 에러"인지 상세 로그를
#     Slack + Telegram 으로 통보. 전 단계 통과 시 시작/종료/소요시간과 함께 통보.
#
# 필요한 환경변수(Actions secrets): SLACK_WEBHOOK_URL / TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID
# =============================================================================
set -u
export TZ=Asia/Seoul
export DEBIAN_FRONTEND=noninteractive

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || { echo "ROOT 진입 실패"; exit 1; }
REPO_LABEL="$(basename "${GITHUB_REPOSITORY:-$ROOT}")"
CILOG="$ROOT/log/ci"
mkdir -p "$CILOG"
CIENV="$CILOG/ci.env"

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
step_tools() {
    local rc=0
    echo "docker:  $(docker --version 2>&1 || { echo 'MISSING'; rc=1; })"
    echo "compose: $(docker compose version 2>&1 || { echo 'MISSING'; rc=1; })"
    echo "jq:      $(jq --version 2>&1 || { echo 'MISSING'; rc=1; })"
    echo "curl:    $(curl --version 2>&1 | head -1 || true)"
    echo "python:  $(python3 --version 2>&1 || true)"
    echo "php:     $(php --version 2>&1 | head -1 || echo '(php 미설치 — php 샘플은 WARN)')"
    return $rc
}

step_prepare() {
    echo "### 런타임 로그 디렉토리 생성 ###"
    for d in nginx gunicorn gunicorn/celery gunicorn/celerybeat \
             uvicorn uvicorn/celery uvicorn/celerybeat \
             uwsgi uwsgi/celery uwsgi/celerybeat \
             daphne daphne/celery daphne/celerybeat php-fpm supervisor; do
        mkdir -p "$ROOT/log/$d" && echo "  OK : log/$d"
    done

    echo "### CI 용 .env 생성 (compose 변수 치환용 안전 기본값) ###"
    cat > "$CIENV" <<'EOF'
LOG_DRIVER=json-file
LOG_OPT_MAXF=5
LOG_OPT_MAXS=100m
PROJECT_DIR=django_sample
PROJECT_NAME=django_sample
WORKERS=4
GUNICORN_PORT=8000
GUNICORN_OPITON=--reload
REQUIREMENTS=./requirements.txt
CELERY_BROKER_URL=redis://redis:6379/3
REDIS_PASSWORD=ci-test-redis-pw
FLOWER_ID=admin
FLOWER_PWD=admin
PASSENGER_START_TIMEOUT=3000
TZ=Asia/Seoul
EOF
    # 저장소에 실제 master .env 가 있으면 그 값으로 덮어쓴다(우선).
    if [ -f "$ROOT/compose/master_service/.env" ]; then
        echo "  master_service/.env 병합"
        cat "$ROOT/compose/master_service/.env" >> "$CIENV"
    fi
    echo "  → $CIENV"
    return 0
}

step_compose() {
    local rc=0 found=0
    echo "### web_service / master_service 스택 docker-compose config 검증 ###"
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        found=1
        local dir; dir=$(dirname "$f")
        # 스택 디렉토리에 .env 가 없으면 CI 기본 .env 를 임시 배치
        local placed=0
        if [ ! -f "$dir/.env" ]; then cp "$CIENV" "$dir/.env"; placed=1; fi
        echo "--- config: $f ---"
        if docker compose --env-file "$CIENV" -f "$f" config -q; then
            echo "  PASS : $f"
        else
            echo "  FAIL : $f"; rc=1
        fi
        [ "$placed" -eq 1 ] && rm -f "$dir/.env"
    done < <(find "$ROOT/compose/web_service" "$ROOT/compose/master_service" \
                -maxdepth 2 -name 'docker-compose*.yml' 2>/dev/null | sort)
    [ "$found" -eq 1 ] || { echo "  검증할 compose 파일 없음"; rc=1; }
    return $rc
}

step_shell_syntax() {
    local rc=0 n=0
    echo "### 셸 스크립트 문법(bash -n) 검증 — 대화형 스크립트도 안전 ###"
    while IFS= read -r s; do
        n=$((n+1))
        if bash -n "$s"; then
            echo "  OK : ${s#$ROOT/}"
        else
            echo "  FAIL : ${s#$ROOT/}"; rc=1
        fi
    done < <(find "$ROOT/script" "$ROOT/config" "$ROOT/docker" -name '*.sh' 2>/dev/null | sort)
    echo "  검사 스크립트 수: $n"
    return $rc
}

step_build() {
    local rc=0 found=0
    echo "### docker/** 의 모든 Dockerfile 빌드 ###"
    : > "$CILOG/build_summary.txt"
    while IFS= read -r df; do
        [ -z "$df" ] && continue
        found=1
        local dir; dir=$(dirname "$df")
        local rel="${dir#$ROOT/docker/}"
        local tag; tag="ci-test/$(printf '%s' "$rel" | tr '/' '-' | tr '[:upper:]' '[:lower:]')"
        local bf; bf="$(basename "$df")"
        local start end el ec
        echo "--- BUILD: $tag  (-f $df) ---"
        start=$(date +%s)
        docker build -f "$df" -t "$tag" "$dir" > "$CILOG/build_$(basename "$dir")_${bf}.log" 2>&1
        ec=$?
        end=$(date +%s); el=$((end-start))
        if [ $ec -eq 0 ]; then
            echo "  PASS ($el s)"
        else
            echo "  FAIL exit=$ec ($el s) — 마지막 40줄:"
            tail -40 "$CILOG/build_$(basename "$dir")_${bf}.log"
            rc=1
        fi
        echo "$tag $ec ${el}s" >> "$CILOG/build_summary.txt"
    done < <(find "$ROOT/docker" -name 'Dockerfile*' 2>/dev/null | sort)
    echo "### build summary ###"; cat "$CILOG/build_summary.txt"
    [ "$found" -eq 1 ] || { echo "  Dockerfile 없음"; rc=1; }
    return $rc
}

step_config() {
    local rc=0
    echo "### config 설정 파일 반영 검증 ###"
    # nginx 메인 conf 존재
    while IFS= read -r d; do
        if [ -f "$d/nginx_conf/nginx.conf" ]; then
            echo "  OK : ${d#$ROOT/}/nginx_conf/nginx.conf"
        fi
    done < <(find "$ROOT/config/web-server/nginx" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
    # app-server 설정(샘플) 존재 확인 — 최소 1개 이상
    local cfgcount; cfgcount=$(find "$ROOT/config/app-server" -type f \( -name '*.conf' -o -name '*.ini' -o -name '*.py' \) 2>/dev/null | wc -l)
    echo "  app-server 설정 파일 수: $cfgcount"
    [ "$cfgcount" -ge 1 ] || { echo "  FAIL : app-server 설정 없음"; rc=1; }
    # 생성기 스크립트 실행권한/문법(이미 step_shell_syntax 에서 문법검증; 여기선 존재 확인)
    local gen; gen=$(find "$ROOT/config/web-server/nginx" -name 'nginx_*conf*.sh' 2>/dev/null | wc -l)
    echo "  nginx conf 생성기 수: $gen"
    return $rc
}

step_logcheck() {
    local rc=0
    echo "### logrotate 정의 + 로그 디렉토리 생성 검증 ###"
    local lr; lr=$(find "$ROOT/script/logrotate" -type f 2>/dev/null | wc -l)
    echo "  logrotate 정의 파일 수: $lr"
    [ "$lr" -ge 1 ] || { echo "  FAIL : logrotate 정의 없음"; rc=1; }
    for d in nginx gunicorn uwsgi php-fpm; do
        if [ -d "$ROOT/log/$d" ]; then echo "  OK : log/$d"; else echo "  MISS : log/$d"; rc=1; fi
    done
    return $rc
}

step_samples() {
    local rc=0
    if [ -d "$ROOT/www/django_sample" ]; then
        echo "### [django_sample] manage.py check ###"
        ( cd "$ROOT/www/django_sample" \
            && pip install -q -r requirements.txt \
            && python manage.py check ) || { echo "django_sample 실패"; rc=1; }
    fi
    if [ -f "$ROOT/www/php_sample/index.php" ]; then
        echo "### [php_sample] php -l ###"
        if command -v php >/dev/null 2>&1; then
            php -l "$ROOT/www/php_sample/index.php" || { echo "php_sample lint 실패"; rc=1; }
        else
            echo "php 미설치 — php_sample lint 건너뜀(WARN)"
        fi
    fi
    return $rc
}

# ----------------------------------------------------------------------------
# 실행 순서
# ----------------------------------------------------------------------------
run_step "필수 도구 확인"            step_tools
run_step "로그디렉토리+CI .env 준비" step_prepare
run_step "docker-compose 적용검증"   step_compose
run_step "셸 스크립트 문법검증"      step_shell_syntax
run_step "docker 이미지 빌드"        step_build
run_step "config 설정 반영검증"      step_config
run_step "스크립트 로그 생성검증"    step_logcheck
run_step "샘플 프로젝트 동작"        step_samples

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

if [ -n "$FAILED_STEP" ]; then
    LOG_TAIL=""
    [ -f "$FAILED_LOG" ] && LOG_TAIL=$(tail -n 30 "$FAILED_LOG" | cut -c1-2000)
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
