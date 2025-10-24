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
# 7. Cron 및 Certbot 설치 (SSL 인증서 자동 갱신)
# ========================================
RUN apt-get install -y cron certbot python3-certbot-nginx

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
# 10. Certbot 자동 갱신 Cron 작업 등록
# ========================================
RUN crontab -l | { cat; echo "0 5 * * 1 certbot renew --quiet --deploy-hook \"nginx -t && service nginx reload\" >> /log/nginx/crontab_$(date +\%Y\%m\%d).log 2>&1"; } | crontab -

# ========================================
# 11. Nginx 시작 스크립트에 Cron 추가
# ========================================
RUN sed -i'' -r -e "/set/i\cron" docker-entrypoint.sh
