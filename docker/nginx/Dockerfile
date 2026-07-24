FROM nginx:latest

# ========================================
# 1. APT 업데이트
# ========================================
RUN apt-get update

# ========================================
# 2. APT 기본 도구 설치 (경고 제거용)
# ========================================
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils

# ========================================
# 3. 타임존 설정 (Asia/Seoul)
# ========================================
ENV TZ=Asia/Seoul
RUN apt-get install -yq tzdata
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# ========================================
# 4. 필요한 패키지 설치
# ========================================
RUN apt-get install -y sendmail wget gnupg

# ========================================
# 7. Cron / Logrotate / Certbot 설치
#    - cron: certbot 자동 갱신 + /etc/cron.daily/logrotate 트리거
#    - logrotate: /etc/logrotate.d/<svc> 처리 (post-install 훅이 cron.daily 등록)
#    - certbot: SSL 인증서 자동 갱신
# ========================================
RUN apt-get install -y cron logrotate certbot python3-certbot-nginx

# ========================================
# 8. CA 인증서 설치 및 업데이트
# ========================================
RUN apt-get update && apt-get install -y ca-certificates
RUN update-ca-certificates
RUN chmod 644 /etc/ssl/certs/ca-certificates.crt

# ========================================
# 9. APT 캐시 정리
# ========================================
RUN apt-get autoremove -y && apt-get clean
RUN rm -rf /var/lib/apt/lists/*

# ========================================
# 9.5 nginx-ultimate-bad-bot-blocker 설치 (build 시점 bake)
#    - 다운로드: install-ngxblocker / setup-ngxblocker / update-ngxblocker 스크립트
#    - install-ngxblocker 의 -c 는 CONF_DIR(스크립트 기본값 /etc/nginx/conf.d)을 통째로
#      덮어쓴다. 따라서 -c /etc/nginx 지정 시 globalblacklist.conf 는
#      /etc/nginx/globalblacklist.conf 에, bots.d/* 는 /etc/nginx/bots.d/* 에 설치된다
#      (conf.d/ 밖 → compose 의 conf.d volume mount 에 가려지지 않고, nginx.conf 의
#      `include /etc/nginx/globalblacklist.conf` 경로와 정확히 일치).
#    - -x 는 dry-run 해제(실제 설치 수행). setup-ngxblocker 는 의도적으로 실행하지 않음 —
#      server 블록 자동 수정은 sample_nginx*.conf 의 명시적 include 로 운영자가 제어.
# ========================================
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    NGXB_URL=https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master && \
    curl -fsSL -o /usr/local/sbin/install-ngxblocker "$NGXB_URL/install-ngxblocker" && \
    curl -fsSL -o /usr/local/sbin/setup-ngxblocker   "$NGXB_URL/setup-ngxblocker"   && \
    curl -fsSL -o /usr/local/sbin/update-ngxblocker  "$NGXB_URL/update-ngxblocker"  && \
    chmod +x /usr/local/sbin/install-ngxblocker \
             /usr/local/sbin/setup-ngxblocker \
             /usr/local/sbin/update-ngxblocker && \
    update-ca-certificates && \
    /usr/local/sbin/install-ngxblocker -x -c /etc/nginx && \
    touch /etc/nginx/bots.d/blacklist-domains.conf && \
    apt-get autoremove -y && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ========================================
# 9.6 ngxblocker 자동 갱신 Cron (6시간 간격)
#    - update-ngxblocker 가 /etc/nginx/conf.d/globalblacklist.conf 를 최신화
#    - 다운로드 성공 시에만 nginx -t && nginx -s reload (잘못된 conf 가 즉시 반영 차단)
# ========================================
RUN crontab -l 2>/dev/null | { cat; echo "0 */6 * * * /usr/local/sbin/update-ngxblocker -c /etc/nginx >> /log/nginx/ngxblocker_$(date +\%Y\%m).log 2>&1 && nginx -t && nginx -s reload"; } | crontab -

# ========================================
# 10. Certbot 자동 갱신 Cron 작업 등록
# ========================================
RUN crontab -l | { cat; echo "0 5 * * 1 certbot renew --quiet --deploy-hook \"nginx -t && service nginx reload\" >> /log/nginx/crontab_$(date +\%Y\%m\%d).log 2>&1"; } | crontab -

# ========================================
# 11. Nginx 시작 스크립트에 Cron 추가
# ========================================
RUN sed -i'' -r -e "/set/i\cron" docker-entrypoint.sh
