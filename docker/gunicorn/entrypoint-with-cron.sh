#!/usr/bin/env bash
# =============================================================================
# Container ENTRYPOINT — start cron then exec the app
#
# 역할:
#   1) logrotate dropin 권한 sanitize.
#      Windows/WSL bind mount 가 /etc/logrotate.d/* 를 0777 로 노출하면
#      logrotate 가 "Potentially dangerous mode" 로 거부한다.
#      → /run/logrotate.d/ 로 mode 0644 사본을 만들어 회전한다.
#      (logrotate include 경로는 운영자가 /etc/logrotate.d/* 대신
#       /run/logrotate.d/* 를 가리키는 dropin 을 추가하거나,
#       기본 /etc/logrotate.d/* 를 그대로 사용해도 됨 — 본 sanitize 는
#       0777 bind mount 환경에서 명시적으로 안전한 사본을 만들어 두는 역할.)
#
#   2) cron 데몬 기동 (백그라운드).
#      Dockerfile 이 crontab 에 일일 02:00 항목으로 logrotate-all.sh 를
#      등록해 두었으므로, cron 만 떠 있으면 (1) 에서 sanitize 한
#      /run/logrotate.d/* 가 매일 회전된다.
#      (Debian 기본 /etc/cron.daily/logrotate 는 /etc/logrotate.conf 만 보고
#       /etc/logrotate.d/* (0777 mount) 를 직접 처리하므로 의존하지 않는다.)
#
#   3) docker-compose 의 `command:` (또는 베이스 이미지 CMD) 를
#      그대로 PID 1 으로 exec — 시그널/zombie reaping 정합성 보존.
# =============================================================================
set -eo pipefail

# (1) logrotate dropin 권한 정리 (0777 bind mount 대응)
mkdir -p /run/logrotate.d
if [ -d /etc/logrotate.d ]; then
    for f in /etc/logrotate.d/*; do
        [ -f "$f" ] || continue
        cp -f "$f" "/run/logrotate.d/$(basename "$f")"
        chmod 644 "/run/logrotate.d/$(basename "$f")"
    done
fi

# (2) cron 데몬 기동
if command -v cron >/dev/null 2>&1; then
    cron || echo "[entrypoint] WARNING: cron failed to start; logrotate will not run."
fi

if [[ $# -eq 0 ]]; then
    echo "[entrypoint] ERROR: no command supplied."
    exit 64
fi

exec "$@"
