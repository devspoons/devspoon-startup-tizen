#!/usr/bin/env bash
# =============================================================================
# django_sample secrets.json 부트스트랩 헬퍼 (테스트/CI 전용)
#
# 배경
#   www/django_sample/config/settings.py:26 이 secrets.json 을 무조건 읽는다.
#   50f7505 commit 에서 해당 파일이 추적 해제(.gitignore: www/*/secrets.json)되어
#   새 체크아웃(=GitHub Actions 러너)에는 존재하지 않는다 → FileNotFoundError.
#
# 정책
#   단일 출처는 추적되는 www/django_sample/secrets.json.example 이다.
#   테스트/CI 는 파일이 없을 때만 .example 을 복사한다(운영자 파일은 절대 덮어쓰지 않음).
#   운영 배포는 이 헬퍼를 쓰지 않고 실제 SECRET_KEY 를 직접 배치한다.
#
# 사용
#   source "$ROOT/script/lib/django_secrets.sh"
#   ensure_django_secrets "$ROOT"      # ROOT 생략 시 이 스크립트 기준 저장소 루트
# =============================================================================

ensure_django_secrets() {
    local root="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    local target="$root/www/django_sample/secrets.json"
    local example="$root/www/django_sample/secrets.json.example"

    if [ -f "$target" ]; then
        echo "  secrets.json 존재 — 그대로 사용"
    elif [ -f "$example" ]; then
        cp "$example" "$target" || { echo "  FAIL : secrets.json 생성 실패"; return 1; }
        echo "  secrets.json 생성 (secrets.json.example 복사, 테스트 전용)"
    else
        echo "  FAIL : secrets.json / secrets.json.example 둘 다 없음 ($example)"
        return 1
    fi

    chmod 644 "$target" 2>/dev/null || true
    return 0
}
