#!/usr/bin/env bash
# =============================================================================
# django_sample secrets.json 부트스트랩 헬퍼
#
# 배경
#   www/django_sample/config/settings.py:26 이 secrets.json 을 무조건 읽는다.
#   secrets.json 은 추적하지 않으므로(.gitignore: www/*/secrets.json) 새 체크아웃에는 없다.
#
# 정책
#   secrets.json.example 은 키 이름 문서이고, 값은 이 헬퍼가 무작위로 생성한다(권한 600).
#   테스트·CI·운영자 최초 설정에 사용하며, 기존 파일은 내용·권한 모두 절대 덮어쓰지 않는다.
#
# 사용
#   bash -c '. script/lib/django_secrets.sh && ensure_django_secrets'   # 저장소 루트에서
#   source "$ROOT/script/lib/django_secrets.sh"; ensure_django_secrets "$ROOT"
# =============================================================================

ensure_django_secrets() {
    local root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    local target="$root/www/django_sample/secrets.json"
    if [ -f "$target" ]; then echo "  secrets.json 존재 — 그대로 사용"; return 0; fi
    command -v openssl >/dev/null 2>&1 || { echo "  FAIL : openssl 없음 — SECRET_KEY 생성 불가"; return 1; }
    ( umask 077
      printf '{\n  "SECRET_KEY": "%s"\n}\n' "$(openssl rand -base64 50 | tr -d '\n')" > "$target" ) \
        || { echo "  FAIL : secrets.json 생성 실패"; return 1; }
    chmod 600 "$target"
    echo "  secrets.json 생성 (무작위 SECRET_KEY, 600)"
}

# .env 의 비밀값(DJANGO_SECRET_KEY·REDIS_PASSWORD·FLOWER_PWD) 중 줄이 있는데 비어 있거나 옛 CHANGE_ME_* 인 것만 무작위 값으로 채운다.
# compose 는 이 값들을 :? 필수로 검사한다. 이미 값이 있으면 절대 바꾸지 않는다 — 운영자 최초 설정 한 줄(저장소 루트):
#   bash -c '. script/lib/django_secrets.sh && ensure_env_secrets compose/web-service/nginx_gunicorn/.env'
ensure_env_secrets() {
    local envf="${1:?사용: ensure_env_secrets <.env 경로>}" k len val n=0
    [ -f "$envf" ] || { echo "  FAIL : $envf 없음 — 먼저 .env-example 을 .env 로 복사"; return 1; }
    command -v openssl >/dev/null 2>&1 || { echo "  FAIL : openssl 없음 — 비밀값 생성 불가"; return 1; }
    for k in DJANGO_SECRET_KEY:50 REDIS_PASSWORD:32 FLOWER_PWD:32; do
        len=${k#*:}; k=${k%%:*}
        grep -qE "^${k}=(CHANGE_ME_[A-Za-z0-9_]*)?\$" "$envf" || continue
        val=$(openssl rand -hex "$len")
        sed -i "s|^${k}=.*|${k}=${val}|" "$envf"
        echo "  $k 생성"; n=$((n+1))
    done
    echo "  비밀값 $n 개 생성 — 기존 값은 그대로 ($envf)"
}
