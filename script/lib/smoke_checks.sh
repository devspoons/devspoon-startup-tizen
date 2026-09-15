#!/usr/bin/env bash
# =============================================================================
# s3 스택 스모크 순수 판정 — 함수 정의만(최상위에 docker·curl·cd·exit 등 명령 없음).
#   s3_stack_smoke.sh 가 source 하고, s6 6.35 가 source 해 단위 검사한다.
#
#   logrotate_dry_ok <rc> <output>        # 3B.15
#   lock_version <package> <uv.lock>      # 3C
#   env_missing <.env-example> <.env>     # 3B.1
# =============================================================================
# logrotate -d 판정 — rc 0 이고 전체 출력에 "Handling N logs"(N≥1). 이 행은 출력 앞부분이라 tail 로 자르면 항상 FAIL (TST-R13-01)
logrotate_dry_ok() {
    [ "$1" = 0 ] && grep -qE '^Handling [1-9][0-9]* logs' <<<"$2"
}
# uv.lock 의 패키지 버전 — 기대 버전을 스크립트에 적지 않는다(버전을 올려도 s3 무수정) (TST-R13-02)
lock_version() {
    awk -v p="$1" '$0 == "name = \"" p "\"" { getline; gsub(/^version = "|"$/, ""); print; exit }' "$2" 2>/dev/null
}
# 스택 .env-example 키 중 .env 에 없는 키를 출력 — 필수 키는 스택마다 다르다(php 는 PROJECT_DIR·FLOWER_* 없음) (TST-R13-03). 예시 키 0 이면 rc 1
env_missing() {
    local keys k
    keys=$(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$1" 2>/dev/null | tr -d =)
    [ -n "$keys" ] || return 1
    for k in $keys; do grep -qE "^$k=" "$2" 2>/dev/null || printf '%s ' "$k"; done
}
