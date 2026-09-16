#!/usr/bin/env bash
# 통합 테스트 시작 가능 여부 자동 점검
# Usage:  bash script/test/preflight.sh
# Exit:   0 = PASS (테스트 시작 가능), 1 = FAIL (선결 결격)
#
# 본 스크립트는 read-only — 어떤 상태도 변경하지 않는다.

set -u

errs=0
warns=0
ROOT=${ROOT:-$(pwd)}

# ----- helper -----
check() {
    local desc=$1 cmd=$2
    if eval "$cmd" >/dev/null 2>&1; then
        printf "  [OK]    %s\n" "$desc"
    else
        printf "  [MISS]  %s\n" "$desc"
        errs=$((errs + 1))
    fi
}
warn() {
    local desc=$1 cmd=$2
    if eval "$cmd" >/dev/null 2>&1; then
        printf "  [OK]    %s\n" "$desc"
    else
        printf "  [WARN]  %s\n" "$desc"
        warns=$((warns + 1))
    fi
}

# ----- (1) 도구 -----
echo "[1] Required tools"
check "docker (>=24)"          "[ \$(docker version -f '{{.Server.Version}}' | cut -d. -f1) -ge 24 ]"
check "docker compose (v2)"    "docker compose version"
# buildx 는 lock 추가 빌드 컨텍스트(`--build-context`/`additional_contexts`)에 필수다. 존재 확인만으로는
# 부족하다 — Docker Desktop 잔재 cli-plugins 심볼릭 링크가 스테일이면 stat 은 통과하고 실행에서만 깨진다.
check "docker buildx (실행 가능 — 실패 시 cli-plugins/docker-buildx 스테일 링크 확인)" "docker buildx version"
check "jq"                     "jq --version"
check "curl"                   "curl --version"
check "openssl"                "openssl version"
warn  "wrk (load test, optional)" "wrk --version 2>&1 | head -1"

# ----- (2) 리포 파일 -----
echo "[2] Repository files"
# .env 는 운영 자격증명이라 git 추적되지 않는다(런타임에 .env-example 에서 생성).
# 따라서 테스트 시작 전제로는 추적되는 템플릿 .env-example 의 존재를 확인한다.
# 경로는 web_service(underscore) — 이 저장소의 compose 디렉터리 이름.
check ".env-example (nginx_gunicorn)"  "test -f $ROOT/compose/web_service/nginx_gunicorn/.env-example"
check ".env-example (nginx_uvicorn)"   "test -f $ROOT/compose/web_service/nginx_uvicorn/.env-example"
check ".env-example (nginx_daphne)"    "test -f $ROOT/compose/web_service/nginx_daphne/.env-example"
check ".env-example (nginx_uwsgi)"     "test -f $ROOT/compose/web_service/nginx_uwsgi/.env-example"
check ".env-example (nginx_php)"       "test -f $ROOT/compose/web_service/nginx_php/.env-example"
check "Dockerfile (gunicorn)"  "test -f $ROOT/docker/gunicorn/Dockerfile"
check "Dockerfile (uwsgi)"     "test -f $ROOT/docker/uwsgi/Dockerfile"
check "Dockerfile (nginx)"     "test -f $ROOT/docker/nginx/Dockerfile"
check "Dockerfile (php-fpm)" "test -f $ROOT/docker/php-fpm/Dockerfile"
check "entrypoint-with-cron (gunicorn)" "test -f $ROOT/docker/gunicorn/entrypoint-with-cron.sh"
check "entrypoint-with-cron (uwsgi)"    "test -f $ROOT/docker/uwsgi/entrypoint-with-cron.sh"
check "pyproject.toml"         "test -f $ROOT/www/django_sample/pyproject.toml"
check "requirements.txt"       "test -f $ROOT/www/django_sample/requirements.txt"
check "letsencrypt.sh"         "test -f $ROOT/script/letsencrypt.sh"

# ----- (3) 회귀 / 디자인 정합 (read-only grep) -----
echo "[3] Design invariants"
check "logrotate folder (not 'loglotate')" \
      "test -d $ROOT/script/logrotate && ! test -d $ROOT/script/loglotate"
check "log/ has .gitkeep >= 11" \
      "[ \$(find $ROOT/log/ -name .gitkeep 2>/dev/null | wc -l) -ge 11 ]"
check "pyproject.toml is PEP 621 (no [tool.poetry])" \
      "grep -q '^\[project\]' $ROOT/www/django_sample/pyproject.toml && \
       ! grep -q '^\[tool.poetry\]' $ROOT/www/django_sample/pyproject.toml"
check "Dockerfile UV_PROJECT_ENVIRONMENT=/usr/local (gunicorn)" \
      "grep -q 'UV_PROJECT_ENVIRONMENT=/usr/local' $ROOT/docker/gunicorn/Dockerfile"
check "Dockerfile UV_PROJECT_ENVIRONMENT=/usr/local (uwsgi)" \
      "grep -q 'UV_PROJECT_ENVIRONMENT=/usr/local' $ROOT/docker/uwsgi/Dockerfile"
# FROM 은 1행이 아닐 수 있다(라이선스/설명 헤더 주석 뒤, 또는 multi-stage 의 builder 단계).
# head -1 가정은 깨지므로 파일 전체에서 FROM 라인을 grep 한다.
check "Dockerfile FROM ubuntu:24.04 (gunicorn)" \
      "grep -q '^FROM ubuntu:24.04' $ROOT/docker/gunicorn/Dockerfile"
check "Dockerfile FROM ubuntu:24.04 (uwsgi)" \
      "grep -q '^FROM ubuntu:24.04' $ROOT/docker/uwsgi/Dockerfile"
check "Dockerfile FROM nginx:1.27 (nginx)" \
      "grep -qE '^FROM nginx:1\.27' $ROOT/docker/nginx/Dockerfile"
check "compose: no poetry references" \
      "! grep -rq 'poetry install\|poetry config' $ROOT/compose/"
check "compose: no 'uv run' in active commands" \
      "! grep -rqE '^\s*command:.*uv run' $ROOT/compose/"
check "compose: no 'service nginx restart' (regression)" \
      "! grep -rnE 'service[[:space:]]+nginx[[:space:]]+(restart|reload)' $ROOT/docker/ $ROOT/script/ $ROOT/compose/ \
         --exclude-dir=test 2>/dev/null \
         | grep -vE ':[0-9]+:[[:space:]]*#' \
         | grep -q ."
check "uwsgi.ini py-autoreload=0" \
      "grep -qE '^py-autoreload\s*=\s*0' $ROOT/config/app-server/uwsgi/uwsgi.ini"

# ----- (4) 호스트 환경 (정보성, FAIL 아님) -----
echo "[4] Host environment (informational)"
warn  "WSL2 detected"                "grep -qi microsoft /proc/version"
warn  "Disk free >= 20GB at \$PWD"   "[ \$(df -BG --output=avail . | tail -1 | tr -dc 0-9) -ge 20 ]"
warn  "net.core.somaxconn >= 4096"   "[ \$(sysctl -n net.core.somaxconn 2>/dev/null || echo 0) -ge 4096 ]"

# ----- 결과 -----
echo ""
if [ $errs -eq 0 ]; then
    printf "PREFLIGHT PASS — ready to run tests (warnings: %d)\n" "$warns"
    exit 0
fi
printf "PREFLIGHT FAIL — %d issue(s), warnings: %d. Fix before running tests.\n" "$errs" "$warns"
exit 1
