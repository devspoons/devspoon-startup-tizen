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
