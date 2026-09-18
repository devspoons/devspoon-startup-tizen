#!/bin/sh
# ============================================================================
# nginx 기동 전 upstream 호스트 이름 해석 대기 (/docker-entrypoint.d 훅)
#
# conf.d 의 proxy_pass / uwsgi_pass / fastcgi_pass 는 컨테이너 이름(gunicorn-app:8000 등)을
# 직접 가리키고, nginx 는 기동 시점에 그 이름을 해석하지 못하면
#   [emerg] host not found in upstream "..."
# 으로 즉시 종료한다. 다음 경우 app 컨테이너가 잠시 네트워크에서 빠진 순간 webserver 가
# 먼저 올라와 이 오류가 난다 (restart: always 로 곧 되살아나지만 한 번 죽는다):
#   - docker compose restart  : depends_on 순서를 기다리지 않고 서비스를 동시에 재시작
#   - 호스트/도커 데몬 재부팅  : restart 정책 컨테이너가 순서 없이 기동
# 이 훅은 conf 에 적힌 upstream 이름이 모두 해석될 때까지 최대 NGINX_UPSTREAM_WAIT 초
# (기본 30, 0 이면 비활성) 기다린다. 시간이 지나도 해석되지 않으면 경고만 남기고 기동을
# 계속한다 — 설정 오류는 기존과 같이 nginx 가 [emerg] 로 알린다. 항상 exit 0.
#
# 대상에서 제외: unix 소켓, $변수, IP 리터럴, localhost, conf 안에 upstream 블록으로 정의된 이름
#   --list : 대기 없이 추출한 이름만 출력 (회귀 검사용)
#   NGINX_UPSTREAM_CONF : 검사할 conf 파일 glob (기본: conf.d 와 master_service 의 proxy.d)
# ============================================================================
CONF="${NGINX_UPSTREAM_CONF:-/etc/nginx/conf.d/*.conf /etc/nginx/proxy.d/*/*.conf}"
WAIT="${NGINX_UPSTREAM_WAIT:-30}"
case "$WAIT" in ''|*[!0-9]*) WAIT=30 ;; esac

# shellcheck disable=SC2086  # CONF 는 의도적으로 glob 확장
body=$(cat $CONF 2>/dev/null | sed 's/#.*//')
ups=$(printf '%s\n' "$body" | sed -n 's/^[[:space:]]*upstream[[:space:]]\{1,\}\([^[:space:]{]\{1,\}\).*/\1/p' | sort -u)
hosts=$(printf '%s\n' "$body" \
    | grep -oE '(proxy|uwsgi|fastcgi|grpc|scgi)_pass[[:space:]]+[^;[:space:]]+' \
    | awk '{print $2}' \
    | sed -E 's#^[a-zA-Z0-9]+://##; s#^unix:.*#unix:#; s#/.*$##; s#:[0-9]+$##' \
    | grep -vE '^(unix:|\$|[0-9.]+$|\[|localhost$)' \
    | sort -u)
for u in $ups; do hosts=$(printf '%s\n' "$hosts" | grep -vxF "$u"); done

if [ "${1:-}" = "--list" ]; then
    [ -n "$hosts" ] && printf '%s\n' "$hosts"
    exit 0
fi
[ -n "$hosts" ] && [ "$WAIT" -gt 0 ] || exit 0

i=0
while :; do
    missing=""
    for h in $hosts; do
        getent hosts "$h" >/dev/null 2>&1 || missing="$missing $h"
    done
    [ -z "$missing" ] && { [ "$i" -gt 0 ] && echo "$0: upstream 이름 해석 완료 (${i}s 대기)"; exit 0; }
    if [ "$i" -ge "$WAIT" ]; then
        echo "$0: 경고 — ${WAIT}s 대기 후에도 upstream 이름 해석 실패:$missing (nginx 기동을 계속 시도)" >&2
        exit 0
    fi
    [ "$i" -eq 0 ] && echo "$0: upstream 이름 해석 대기:$missing (최대 ${WAIT}s)"
    i=$((i + 1))
    sleep 1
done
