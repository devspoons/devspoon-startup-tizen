# =============================================================================
# PHP 8.4 FPM 이미지
# - 베이스: 공식 php:8.4-fpm-bookworm (Debian 12)
# - 멀티버전 경로(/etc/php/X.Y/fpm)가 아닌 단일 경로(/usr/local/etc/php{,-fpm.d}) 사용
# - 컨테이너 내부 PHP 설정 경로 매핑은 compose 의 volumes 에서 명시한다.
# =============================================================================
FROM php:8.4-fpm-bookworm

ENV OS_LOCALE_COUNTRY="en_US"
ENV OS_LOCALE_ENCODING="UTF-8"
ENV OS_LOCALE="en_US.UTF-8"
ENV TZ="Asia/Seoul"
ENV DEBIAN_FRONTEND=noninteractive

# ============================================================================
# 1. 시스템 도구 / 타임존 / locale / 메일 / cron / logrotate 단일 레이어
#    apt-utils, tzdata, locales, sendmail, cron, logrotate, ca-certificates
# ============================================================================
# 타임존 설정 패턴 통일 (gunicorn/uwsgi/nginx Dockerfile 와 동일):
#  - `ln -snf .../localtime` + `echo $TZ > /etc/timezone` 두 줄로 충분.
#  - dpkg-reconfigure tzdata 는 noninteractive 환경에서 추가 효과가 없고
#    기 설정된 /etc/localtime 만 다시 만질 뿐이라 본 Dockerfile 에서는 제거한다.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apt-utils \
        tzdata \
        locales \
        ca-certificates \
        sendmail \
        cron \
        logrotate \
        curl wget git tar vim && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    localedef -i ${OS_LOCALE_COUNTRY} -f ${OS_LOCALE_ENCODING} ${OS_LOCALE} && \
    update-ca-certificates && \
    apt-get autoremove -y && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE} \
    LC_CTYPE=${OS_LOCALE} \
    LC_MESSAGES=${OS_LOCALE}

# ============================================================================
# 2. Cron + logrotate 부트스트랩
#   - php-fpm 본체는 회전 미지원 → 호스트 마운트된 /etc/logrotate.d/php-fpm 사용
#   - cron 데몬은 entrypoint-with-cron.sh 가 백그라운드 기동
#   - logrotate-all.sh : sanitized /run/logrotate.d/* 처리 (WSL 0777 mount 회피)
# ============================================================================
RUN ( crontab -l 2>/dev/null; \
      echo "0 2 * * * /usr/local/bin/logrotate-all.sh >> /log/php-fpm/logrotate.log 2>&1" \
    ) | crontab - \
 && printf '#!/bin/sh\nfor f in /run/logrotate.d/*; do [ -f "$f" ] && /usr/sbin/logrotate -s /var/lib/logrotate/status "$f"; done\n' > /usr/local/bin/logrotate-all.sh \
 && chmod +x /usr/local/bin/logrotate-all.sh

# ============================================================================
# 3. 컨테이너 ENTRYPOINT (cron + 임의 CMD)
#    7.3 와 동일한 entrypoint-with-cron.sh 를 공용으로 사용
# ============================================================================
COPY entrypoint-with-cron.sh /usr/local/bin/entrypoint-with-cron
RUN chmod +x /usr/local/bin/entrypoint-with-cron
ENTRYPOINT ["/usr/local/bin/entrypoint-with-cron"]
CMD ["php-fpm", "--nodaemonize"]
