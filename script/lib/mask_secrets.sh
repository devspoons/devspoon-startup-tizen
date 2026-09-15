#!/usr/bin/env bash
# =============================================================================
# 로그 비밀값 마스킹 필터 — CI 실패 알림 본문과 업로드 아티팩트(log/ci, log/test_run)에 공통 적용
#   mask_secrets              : stdin → stdout
#   mask_secrets_files DIR... : DIR(없으면 건너뜀) 아래 모든 파일을 제자리 치환, 실패 시 rc 1
# 대상 (대소문자 무시)
#   - 식별자 이름에 PASSWORD·PASSWD·PWD·SECRET·TOKEN·_KEY·BASIC_AUTH 가 든 키의 값
#     KEY=값 / KEY: 값 / "KEY": "값"(이스케이프 따옴표·쉼표 포함) / KEY='값'
#   - Authorization 헤더(스킴 + 자격증명), URL userinfo(redis://:pw@host)
#   - redis: --requirepass 값·"값"·'값', redis.conf requirepass 값, JSON 배열 "--requirepass", "값", redis-cli ... -a 값·"값"·'값'
#   - 로그가 잘려 따옴표가 닫히지 않은 값("값…·'값…)은 줄 끝까지 마스킹 (R4-04)
# 과마스킹 방지: 단어 PASS·token 단독, 공백이 낀 문장("invalid token format")은 대상이 아니다 (s6 6.16 단언)
# =============================================================================
MASK_SED=(
    -e 's/(authorization"?[[:space:]]*:[[:space:]]*"?)([A-Za-z]+[[:space:]]+)?[^[:space:]"\x27,]+/\1\2***/Ig'
    -e 's/("--requirepass"[[:space:]]*,[[:space:]]*)"([^"\\]|\\.)*"/\1"***"/Ig'
    -e 's/((^|[^A-Za-z0-9_-])(--)?requirepass[[:space:]]+)"([^"\\]|\\.)*"/\1"***"/Ig'
    -e 's/((^|[^A-Za-z0-9_-])(--)?requirepass[[:space:]]+)\x27[^\x27]*\x27/\1\x27***\x27/Ig'
    -e 's/((^|[^A-Za-z0-9_-])(--)?requirepass[[:space:]]+)("([^"\\]|\\.)*$|\x27[^\x27]*$|[^[:space:]"\x27,]+)/\1***/Ig'
    -e 's/(redis-cli([[:space:]]+[^[:space:]]+)*[[:space:]]+-a[[:space:]]+)("([^"\\]|\\.)*("|$)|\x27[^\x27]*(\x27|$)|[^[:space:]]+)/\1***/Ig'
    -e 's/((^|[^A-Za-z0-9_])[A-Za-z0-9_]*(PASSWORD|PASSWD|PWD|SECRET|TOKEN|_KEY|BASIC_AUTH)[A-Za-z0-9_]*"?[[:space:]]*[=:][[:space:]]*)"([^"\\]|\\.)*"/\1"***"/Ig'
    -e 's/((^|[^A-Za-z0-9_])[A-Za-z0-9_]*(PASSWORD|PASSWD|PWD|SECRET|TOKEN|_KEY|BASIC_AUTH)[A-Za-z0-9_]*[[:space:]]*[=:][[:space:]]*)\x27[^\x27]*\x27/\1\x27***\x27/Ig'
    -e 's/((^|[^A-Za-z0-9_])[A-Za-z0-9_]*(PASSWORD|PASSWD|PWD|SECRET|TOKEN|_KEY|BASIC_AUTH)[A-Za-z0-9_]*[[:space:]]*[=:][[:space:]]*)("([^"\\]|\\.)*$|\x27[^\x27]*$|[^[:space:]"\x27]+)/\1***/Ig'
    -e 's#(://[^:/@[:space:]]*:)[^@[:space:]]+@#\1***@#g'
)
mask_secrets() { sed -E "${MASK_SED[@]}"; }
mask_secrets_files() {
    local d rc=0
    for d in "$@"; do
        [ -e "$d" ] || continue
        find "$d" -type f -exec sed -i -E "${MASK_SED[@]}" {} + || rc=1
    done
    return "$rc"
}
