FROM nginx:1.27-bookworm

ENV TZ=Asia/Seoul \
    DEBIAN_FRONTEND=noninteractive

# ============================================================================
# 1. 시스템 도구 / 타임존 / cron / certbot / CA 단일 레이어
#    - apt-get update + install + cache cleanup 한 RUN 으로 묶어
#      이미지 크기 및 layer 수를 절감
# ============================================================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apt-utils \
        tzdata \
        ca-certificates \
        sendmail wget gnupg \
        cron logrotate certbot python3-certbot-nginx && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    update-ca-certificates && \
    chmod 644 /etc/ssl/certs/ca-certificates.crt && \
    apt-get autoremove -y && apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ============================================================================
# 2. Cron 작업 등록 (certbot 갱신 + daily logrotate)
#    - certbot renew (월요일 05:00) : deploy-hook 으로 nginx -t 후 graceful reload
#    - logrotate     (매일  02:00) : sanitized /run/logrotate.d/* 처리 (WSL/Windows
#                                     bind-mount 가 0777 로 노출되는 /etc/logrotate.d
#                                     를 logrotate 가 거부하는 문제 회피)
#    - logrotate-all.sh : /run/logrotate.d/*.conf 를 개별 호출 — Debian 기본
#                           /etc/cron.daily/logrotate 는 /etc/logrotate.conf 만 보고
#                           /etc/logrotate.d/* (0777 mount) 를 직접 처리하므로
#                           sanitize 효과가 없음 → 별도 entry 가 필요.
# ============================================================================
RUN ( crontab -l 2>/dev/null; \
      echo "0 5 * * 1 certbot renew --quiet --deploy-hook \"nginx -t && nginx -s reload\" >> /log/nginx/crontab_\$(date +\%Y\%m\%d).log 2>&1"; \
      echo "0 2 * * * /usr/local/bin/logrotate-all.sh >> /log/nginx/logrotate.log 2>&1" \
    ) | crontab - \
 && printf '#!/bin/sh\nfor f in /run/logrotate.d/*; do [ -f "$f" ] && /usr/sbin/logrotate -s /var/lib/logrotate/status "$f"; done\n' > /usr/local/bin/logrotate-all.sh \
 && chmod +x /usr/local/bin/logrotate-all.sh

# ============================================================================
# 3. nginx-ultimate-bad-bot-blocker 설치 (build 시점에 초기 데이터 bake-in)
#    - 다운로드: install-ngxblocker / setup-ngxblocker / update-ngxblocker 스크립트
#    - install-ngxblocker -x -c /etc/nginx: /etc/nginx/globalblacklist.conf 와 /etc/nginx/bots.d/* 생성
#      → 기존 정적 bad_bot.conf 를 globalblacklist.conf 가 대체 ($bad_bot 변수 동일)
#    - setup-ngxblocker 는 의도적으로 실행하지 않음 — server 블록 자동 수정은 sample_nginx*.conf
#      의 명시적 include 로 운영자가 제어
# ============================================================================
# 공급망 하드닝: 'master' 부동 참조 대신 고정 커밋 SHA 에서 받고 sha256 으로 무결성을 검증한다.
#   - master 는 업스트림 계정 탈취/브랜치 하이재킹 시 임의 코드가 엣지 이미지에 무검증 유입될 수 있다.
#   - 갱신 시: NGXBLOCKER_REF(커밋 SHA)와 아래 3개 sha256 값을 함께 올린다.
#   - (참고: 아래 6시간 update-ngxblocker cron 은 런타임에 차단 '리스트 데이터'를 받지만 코드 실행은
#      아니다. 실행 가능한 스크립트 본체를 고정·검증하는 것이 1차 방어선.)
ARG NGXBLOCKER_REF=782785ccbb0fbf3592046b8d2d97ea059d8d7d46
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    NGXB_URL=https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/${NGXBLOCKER_REF} && \
    curl -fsSL -o /usr/local/sbin/install-ngxblocker "$NGXB_URL/install-ngxblocker" && \
    curl -fsSL -o /usr/local/sbin/setup-ngxblocker   "$NGXB_URL/setup-ngxblocker"   && \
    curl -fsSL -o /usr/local/sbin/update-ngxblocker  "$NGXB_URL/update-ngxblocker"  && \
    printf '%s  %s\n' \
      92db080637ec21883f608abd0a512678780a267c3d56f3e683b641ad11079aea /usr/local/sbin/install-ngxblocker \
      cb112fede0bfad2935fc5ae9be7f94f7259d2a03b41d7cd5034774da9f3db38e /usr/local/sbin/setup-ngxblocker \
      6cbc322c382d7d9370faef2ef41717211ab0f328290291c259ff7de226ae68d7 /usr/local/sbin/update-ngxblocker \
      | sha256sum -c - && \
    chmod +x /usr/local/sbin/install-ngxblocker \
             /usr/local/sbin/setup-ngxblocker \
             /usr/local/sbin/update-ngxblocker && \
    # -c /etc/nginx 로 globalblacklist.conf 를 conf.d/ 밖에 둠.
    # 이유: compose 가 conf.d/ 디렉터리 전체를 호스트에서 mount → image 의 globalblacklist.conf 가 가려짐.
    #       /etc/nginx/ 는 mount 되지 않으므로 image 의 globalblacklist.conf 가 그대로 보임.
    /usr/local/sbin/install-ngxblocker -x -c /etc/nginx && \
    # install-ngxblocker 가 만들지 않는 사용자 커스텀 파일은 빈 파일로 생성 (sample_nginx*.conf include 깨짐 방지)
    touch /etc/nginx/bots.d/blacklist-domains.conf && \
    # botblocker-nginx-settings.conf 는 설치되지만 nginx.conf 가 include 하지 않는다 (D-1 B).
    # (이 파일의 addr/flood zone 키가 $binary_remote_addr 라 정상 사용자까지 제한하므로, nginx.conf 가
    #  같은 이름의 zone 을 $bot_iplimit 키로 정의하고 해시 크기 지시어만 옮겨 두었다.)
    apt-get autoremove -y && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ============================================================================
# 4. ngxblocker 자동 갱신 Cron 등록 (6시간 간격)
#    - update-ngxblocker 가 /etc/nginx/globalblacklist.conf 를 최신화
#    - 다운로드 성공 시에만 nginx -t && nginx -s reload (잘못된 conf 가 prod 즉시 반영 차단)
# ============================================================================
RUN crontab -l 2>/dev/null | { cat; echo "0 */6 * * * /usr/local/sbin/update-ngxblocker -c /etc/nginx >> /log/nginx/ngxblocker_\$(date +\%Y\%m).log 2>&1 && nginx -t && nginx -s reload"; } | crontab -

# ============================================================================
# 5. 컨테이너 시작 시 cron 데몬 기동 + logrotate dropin sanitize
#    - vendor 의 docker-entrypoint.sh 를 sed 로 패치하지 않고,
#      nginx 공식 이미지가 기본 지원하는 /docker-entrypoint.d/*.sh 훅을 사용
#      (nginx 기동 직전에 알파벳 순으로 실행됨)
#    - (1) /etc/logrotate.d/* 는 Windows/WSL bind mount 가 0777 로 노출되어
#          logrotate 가 "Potentially dangerous mode" 로 거부한다. /run/logrotate.d/
#          로 mode 0644 사본을 만들어 두면 logrotate-all.sh 가 안전하게 처리.
#    - (2) cron 데몬 기동 — certbot renew + daily logrotate + ngxblocker 갱신 트리거.
# ============================================================================
RUN printf '#!/bin/sh\nset -e\n# (1) logrotate dropin 권한 정리: bind mount 가 0777 인 경우 sanitized 사본을 /run/logrotate.d/ 로 복사 (mode 0644)\nmkdir -p /run/logrotate.d\nif [ -d /etc/logrotate.d ]; then\n  for f in /etc/logrotate.d/*; do\n    [ -f "$f" ] || continue\n    cp -f "$f" "/run/logrotate.d/$(basename "$f")"\n    chmod 644 "/run/logrotate.d/$(basename "$f")"\n  done\nfi\n# (2) certbot/logrotate/ngxblocker 용 cron 데몬 기동\ncommand -v cron >/dev/null 2>&1 && cron || true\n' > /docker-entrypoint.d/40-start-cron.sh \
 && chmod +x /docker-entrypoint.d/40-start-cron.sh

# ============================================================================
# 6. HTTPS default_server 용 dummy 인증서 (방법 1: ssl_reject_handshake)
#    - SNI 미매칭 / IP 직접 HTTPS 접근에 대한 정보 누출 차단을 위해 conf.d/default.conf
#      의 443 default_server 블록을 활성화한다. 이 블록은 ssl_reject_handshake on; 으로
#      handshake 자체를 거부하지만, nginx 가 listen 443 ssl 블록을 파싱하려면 문법상
#      ssl_certificate / ssl_certificate_key 가 반드시 있어야 한다.
#    - 이 dummy 인증서는 응답에 노출되지 않으므로 도메인 이름이 의미 없다. CN=default-reject.
#    - openssl 은 nginx:1.27-bookworm 이미지에 기본 포함되어 있음.
#    - 자동 갱신 불필요 (10년 유효, 응답에 안 나가므로 만료/체인 검증 무관).
#    - 저장 경로: /etc/nginx/ssl/default/
#        · 과거 compose 가 ssl/certs 를 /etc/ssl/certs 에 bind-mount 해 빌드 산출물을 가렸던 이력이 있어
#          (현재 해당 마운트는 제거됨) mount 대상이 아닌 /etc/nginx/ 아래에 둔다.
#          (globalblacklist.conf 가 /etc/nginx/ 에 위치한 것과 같은 이유)
# ============================================================================
RUN mkdir -p /etc/nginx/ssl/default && \
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
        -subj "/CN=default-reject" \
        -keyout /etc/nginx/ssl/default/privkey.pem \
        -out   /etc/nginx/ssl/default/fullchain.pem && \
    chmod 644 /etc/nginx/ssl/default/fullchain.pem && \
    chmod 600 /etc/nginx/ssl/default/privkey.pem

# ============================================================================
# 7. CA 인증서 번들 최종 재생성 (★ 마지막 단계)
#    - 이전 RUN 단계들이 apt-get autoremove/clean 으로 /etc/ssl/certs/ 를 비울 수 있음
#    - update-ngxblocker 가 raw.githubusercontent.com 으로 curl 할 때 ca-certificates.crt 필수
#    - 본 RUN 을 Dockerfile 최하단에 두어 다른 RUN 의 cleanup 영향을 받지 않게 함
# ============================================================================
RUN update-ca-certificates && \
    test -s /etc/ssl/certs/ca-certificates.crt && \
    chmod 644 /etc/ssl/certs/ca-certificates.crt

# ============================================================================
# 8. DH 파라미터(ssl_dhparam) 빌드 시 1회 생성하여 이미지에 굽는다
#    - 현재 cipher 정책은 ECDHE 전용(TLS1.2/1.3)이라 실제 핸드셰이크엔 쓰이지 않지만,
#      향후 DHE 추가 대비 + nginx ssl_dhparam 지시어 유지를 위해 단일 공유본을 둔다.
#      (dhparam 은 비밀이 아니고 도메인 종속도 아니므로 전 도메인 공유로 충분)
#    - 위치는 /etc/nginx/dhparam.pem — compose 는 /etc/nginx/{conf.d,nginx.conf,proxy_params}
#      만 개별 마운트하므로 이 파일은 가려지지 않는다. (과거엔 /etc/ssl/certs 아래에 두어
#      호스트 볼륨이 시스템 CA 번들 ca-certificates.crt 를 가려 certbot 이 실패했었음)
# ============================================================================
RUN openssl dhparam -out /etc/nginx/dhparam.pem 2048 && \
    chmod 644 /etc/nginx/dhparam.pem

# ============================================================================
# 9. dhparam 백업/복원 훅 (nginx 기동 전, 마운트 적용 후 실행)
#    - 호스트 볼륨(/etc/nginx/dhparam-backup, compose 에서 ./ssl/dhparam 마운트)에
#      백업본이 있으면 복원해 사용 → 이미지를 재빌드해 dhparam 이 새로 구워져도
#      운영 중이던 동일 키를 유지한다 (docker compose down 후 up 시에도 동일 키 유지).
#    - 백업본이 없으면(최초 기동) 이미지에 구운 dhparam 을 백업 디렉터리로 복사해 둔다.
#    - nginx 공식 이미지의 /docker-entrypoint.d/*.sh 훅 사용 → nginx 기동 직전 알파벳 순 실행.
# ============================================================================
RUN printf '#!/bin/sh\nset -e\nBK=/etc/nginx/dhparam-backup/dhparam.pem\nLV=/etc/nginx/dhparam.pem\nmkdir -p /etc/nginx/dhparam-backup\nif [ -s "$BK" ]; then\n  cp -f "$BK" "$LV"\nelse\n  cp -f "$LV" "$BK"\nfi\n' > /docker-entrypoint.d/20-dhparam.sh && \
    chmod +x /docker-entrypoint.d/20-dhparam.sh
