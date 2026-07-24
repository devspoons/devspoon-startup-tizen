#!/usr/bin/env bash
# =============================================================================
# Container ENTRYPOINT — start cron then exec the app
#
# 역할:
#   1) cron 데몬 기동 (백그라운드).
#      Debian/Ubuntu 의 logrotate 패키지 post-install 훅이
#      /etc/cron.daily/logrotate 를 만들어 두므로 cron 만 떠 있으면
#      매일 자동으로 /etc/logrotate.d/* 를 처리한다.
#
#   2) docker-compose 의 `command:` (또는 베이스 이미지 CMD) 를
#      그대로 PID 1 으로 exec — 시그널/zombie reaping 정합성 보존.
# =============================================================================
set -eo pipefail

if command -v cron >/dev/null 2>&1; then
    cron || echo "[entrypoint] WARNING: cron failed to start; logrotate will not run."
fi

if [[ $# -eq 0 ]]; then
    echo "[entrypoint] ERROR: no command supplied."
    exit 64
fi

exec "$@"
