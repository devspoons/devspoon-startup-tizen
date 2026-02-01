FROM nginx:latest

# ========================================
# 1. Environment configuration
# ========================================
ENV TZ=Asia/Seoul
ENV DEBIAN_FRONTEND=noninteractive

# ========================================
# 2. APT update and install base tools
# ========================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    apt-utils \
    tzdata \
    sendmail \
    wget \
    gnupg \
    ca-certificates

# ========================================
# 3. Timezone configuration
# ========================================
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# ========================================
# 4. Install Cron and Certbot for SSL auto-renewal
# ========================================
RUN apt-get install -y --no-install-recommends \
    cron \
    certbot \
    python3-certbot-nginx

# ========================================
# 5. Update CA certificates
# ========================================
RUN update-ca-certificates && \
    chmod 644 /etc/ssl/certs/ca-certificates.crt

# ========================================
# 6. Cleanup APT cache
# ========================================
RUN apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ========================================
# 7. Register Certbot auto-renewal cron job
# ========================================
RUN (crontab -l 2>/dev/null || true; echo "0 5 * * 1 certbot renew --quiet --deploy-hook \"nginx -t && service nginx reload\" >> /var/log/nginx/certbot_renew.log 2>&1") | crontab -

# ========================================
# 8. Add cron startup to Nginx entrypoint
# ========================================
RUN sed -i'' -r -e "/set/i\cron" /docker-entrypoint.sh
