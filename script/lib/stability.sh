#!/usr/bin/env bash
# =============================================================================
# 컨테이너 안정성 판정 — `Up`/running 한 번 관측은 기동 직후 재시작 루프(restart: always)도 통과시킨다.
#   안정화 창(STABLE_WINDOW 초, 기본 15) 전후로 두 번 관측해 모두 running 이고 RestartCount 가 0 으로
#   변하지 않았으며 health 가 healthy 또는 healthcheck 없음(none) 일 때만 안정으로 본다.
#
#   stable_judge "<status restartcount health>" "<status restartcount health>"   # 순수 판정 (s6 6.18 단위 테스트)
#   containers_stable <container-id>...                                           # docker inspect 두 번 + 판정
# =============================================================================
stable_judge() {
    local s1 r1 s2 r2 h2
    read -r s1 r1 _ <<<"$1"
    read -r s2 r2 h2 <<<"$2"
    [ "$s1" = running ] && [ "$s2" = running ] && [ "$r1" = 0 ] && [ "$r2" = 0 ] \
        && { [ "${h2:-none}" = healthy ] || [ "${h2:-none}" = none ]; }
}

_stable_observe() {
    docker inspect -f '{{.State.Status}} {{.RestartCount}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$1" 2>/dev/null
}

containers_stable() {
    local ids=("$@") before=() after i
    [ "${#ids[@]}" -gt 0 ] || return 1
    for i in "${!ids[@]}"; do before[i]=$(_stable_observe "${ids[i]}"); done
    sleep "${STABLE_WINDOW:-15}"
    for i in "${!ids[@]}"; do
        after=$(_stable_observe "${ids[i]}")
        stable_judge "${before[i]}" "$after" || { echo "    unstable ${ids[i]:-<없음>}: [${before[i]}] → [$after]"; return 1; }
    done
}

# HTTP 단언·준비 대기 — compose --wait·healthy 직후에도 nginx/앱이 잠시 연결을 거부할 수 있다 (CL-WP4-R9-FLAKY)
#   http_is <기대코드 정규식> <curl 인자...>   # 불일치 시 실제 받은 코드를 출력하고 1
#   wait_http <기대코드 정규식> <curl 인자...> # WAIT_HTTP_INTERVAL 초(기본 1) 간격 WAIT_HTTP_TRIES 회(기본 30) 폴링, 상한 초과 시 마지막 코드 출력·1
http_is() {
    local want="$1" got; shift
    got=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@")
    [[ "$got" =~ ^($want)$ ]] || { echo "    HTTP $got (기대 $want): ${*: -1}"; return 1; }
}
wait_http() {
    local i
    for i in $(seq "${WAIT_HTTP_TRIES:-30}"); do
        http_is "$@" >/dev/null && return 0
        sleep "${WAIT_HTTP_INTERVAL:-1}"
    done
    echo "    준비 대기 상한 초과 (${WAIT_HTTP_TRIES:-30}회 × ${WAIT_HTTP_INTERVAL:-1}s)"
    http_is "$@"
}
