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

# .env 의 비밀값(DJANGO_SECRET_KEY·REDIS_PASSWORD·FLOWER_PWD)을 무작위 hex 로 채운다. 이미 값이 있는 줄은 절대 바꾸지 않는다.
#   - 비었거나 옛 CHANGE_ME_* 인 줄만 치환(같은 키가 중복돼도 그 줄만). CRLF .env 는 CR 을 무시해 매칭하고 줄끝을 보존
#   - 키 줄이 아예 없으면 같은 폴더 docker-compose.yml 이 ${KEY:?} 로 요구하는 키만 끝에 추가 (이전 .env 업그레이드, php 스택은 REDIS_PASSWORD 만)
#   - 값을 모두 만든 뒤 한 번에 쓴다: openssl 실패 시 FAIL·rc 1·파일 무변경. 생성이 있으면 group/other 권한 제거(600, 더 엄격하면 유지)
# compose 는 이 값들을 :? 필수로 검사한다 — 운영자 최초 설정 한 줄(저장소 루트):
#   bash -c '. script/lib/django_secrets.sh && ensure_env_secrets compose/web-service/nginx_gunicorn/.env'
ensure_env_secrets() {
    local envf="${1:?사용: ensure_env_secrets <.env 경로>}" req k len val tmp set="" app="" names="" n=0
    [ -f "$envf" ] || { echo "  FAIL : $envf 없음 — 먼저 .env-example 을 .env 로 복사"; return 1; }
    command -v openssl >/dev/null 2>&1 || { echo "  FAIL : openssl 없음 — 비밀값 생성 불가"; return 1; }
    req=$(grep -oE '\$\{(DJANGO_SECRET_KEY|REDIS_PASSWORD|FLOWER_PWD):\?' "$(dirname "$envf")/docker-compose.yml" 2>/dev/null)
    for k in DJANGO_SECRET_KEY:50 REDIS_PASSWORD:32 FLOWER_PWD:32; do
        len=${k#*:}; k=${k%%:*}
        if grep -qE "^${k}=(CHANGE_ME_[A-Za-z0-9_]*)?"$'\r?$' "$envf"; then :
        elif ! grep -q "^${k}=" "$envf" && [[ $req == *"{$k:?"* ]]; then app="$app $k"
        else continue; fi
        val=$(openssl rand -hex "$len" 2>/dev/null) && [ "${#val}" -eq $((len * 2)) ] \
            || { echo "  FAIL : openssl rand 실패 — $envf 변경 안 함"; return 1; }
        set="$set $k=$val"; names="$names $k"; n=$((n+1))
    done
    if [ "$n" -gt 0 ]; then
        # 원자적 교체: 같은 폴더 임시 파일에 쓰고 권한(600, 더 엄격하면 유지)·소유자를 맞춘 뒤 mv. 실패 시 원본 불변.
        # 심볼릭 링크 .env 는 링크를 보존하고 대상 파일을 교체한다 (compose 요구 키 조회는 위에서 링크 경로 기준으로 끝남)
        [ -L "$envf" ] && { envf=$(readlink -f "$envf") || { echo "  FAIL : $1 링크 대상 확인 실패"; return 1; }; }
        tmp=$(mktemp "$envf.XXXXXX" 2>/dev/null) || { echo "  FAIL : 임시 파일 생성 실패(폴더 쓰기 불가?) — $envf 변경 안 함"; return 1; }
        if awk -v set="$set" -v app="$app" '
            BEGIN { split(set, a, " "); for (i in a) { p = index(a[i], "="); v[substr(a[i], 1, p - 1)] = substr(a[i], p + 1) } }
            { eol = sub(/\r$/, "") ? "\r" : ""; p = index($0, "="); k = substr($0, 1, p - 1)
              if (p > 1 && (k in v) && substr($0, p + 1) ~ /^(CHANGE_ME_[A-Za-z0-9_]*)?$/) $0 = k "=" v[k]
              printf "%s%s\n", $0, eol }
            END { split(app, b, " "); for (i = 1; i in b; i++) printf "%s=%s%s\n", b[i], v[b[i]], eol }' "$envf" > "$tmp" \
            && chmod --reference="$envf" "$tmp" && chmod go= "$tmp" \
            && { chown --reference="$envf" "$tmp" 2>/dev/null || :; } && mv -f "$tmp" "$envf"; then :
        else rm -f "$tmp"; echo "  FAIL : $envf 쓰기 실패 — 원본 변경 안 함"; return 1; fi
        for k in $names; do echo "  $k 생성"; done
    fi
    echo "  비밀값 $n 개 생성 — 기존 값은 그대로 ($envf)"
}
