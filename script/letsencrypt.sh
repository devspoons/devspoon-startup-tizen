#!/bin/bash
# ============================================================================
# Let's Encrypt 초기 발급 스크립트 — 도메인당 1회 실행
#
# 역할:
#   1) 사용자 입력 (webroot / domain(s) / email) 수집 및 형식 검증
#   2) 이미 발급된 도메인인지 /etc/letsencrypt/live/<domain>/ 존재 여부로 판단
#   3) certbot certonly --webroot 로 SAN 인증서 발급
#
# 비고 (의도적으로 빠진 것):
#   - dhparam: docker/nginx/Dockerfile 섹션 8 에서 /etc/nginx/dhparam.pem 으로
#     이미지에 1회 굽고, /docker-entrypoint.d/20-dhparam.sh 가 호스트 백업/복원을
#     담당한다. 본 스크립트에서는 dhparam 을 만들지 않는다.
#   - 갱신 cron: docker/nginx/Dockerfile 섹션 2 가 SSOT 로 등록한다.
#     본 스크립트에서 crontab 을 건드리면 cron 중복/충돌이 발생하므로 의도적으로 제외.
# ============================================================================

set -eo pipefail

# cron / certbot / python3-certbot-nginx / ca-certificates 는 nginx Dockerfile 에서 설치된다.
# 컨테이너 안에서 1회성 초기 발급용으로 실행되므로 추가 설치는 불필요.
# 외부 호스트에서 단독 실행 시에만 아래 라인의 주석을 해제해서 사용한다.
# apt-get update && apt-get install -y certbot python3-certbot-nginx ca-certificates

# ─────────────────────────────────────────────────────────────────────────────
# (1) webroot 입력 — /www/<webroot>/ 아래에 ACME challenge 가 떨어진다.
#     /www 가 nginx server 블록의 정적 root 와 일치해야 challenge 가 서빙된다.
# ─────────────────────────────────────────────────────────────────────────────
while :
do
    echo -n "Enter the service webroot_folder (under /www/, e.g. django_sample) > "
    read webroot_folder
    echo  "Entered service webroot_folder: $webroot_folder"
    if [[ -z "$webroot_folder" ]]; then
        echo "  (값을 입력하세요)"
        continue
    fi
    if [[ ! "$webroot_folder" =~ ^[A-Za-z0-9._/-]+$ ]]; then
        echo "  (형식 오류 — 허용: [A-Za-z0-9._/-]+)"
        continue
    fi
    if [[ ! -d "/www/$webroot_folder" ]]; then
        echo "  [WARN] /www/$webroot_folder/ 가 존재하지 않습니다."
        echo "  ACME HTTP-01 challenge 는 /www/$webroot_folder/.well-known/acme-challenge/<token>"
        echo "  경로로 떨어지므로 nginx 의 server 블록 root 가 이 디렉토리를 가리키도록"
        echo "  미리 sample_nginx_http.conf 기반 conf 를 생성해 두어야 합니다."
        echo -n "  계속 진행하시겠습니까? [y/N] > "
        read confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || continue
    fi
    break
done

# ─────────────────────────────────────────────────────────────────────────────
# (2) 도메인 입력 — 공백 구분 다중 도메인 → SAN 인증서로 묶어 발급
#     첫 도메인이 live/ 디렉토리명이 되므로 a-record 가 있는 primary 도메인을 먼저.
# ─────────────────────────────────────────────────────────────────────────────
echo
echo "도메인을 공백으로 구분하여 입력하세요. 모두 같은 webroot 를 가리켜야 합니다."
echo "예: 'aaa.com www.aaa.com sub.aaa.com'"
echo "주의: 첫 도메인이 /etc/letsencrypt/live/<domain>/ 의 디렉토리명이 되므로"
echo "       a-record 가 있는 primary domain (예: aaa.com) 을 먼저 두세요."
while :
do
    echo -n "Enter the service domain(s) > "
    read domain
    echo  "Entered service domain: $domain"
    if [[ -z "$domain" ]]; then
        echo "  (값을 입력하세요)"
        continue
    fi
    break
done

# IFS=' ' 로 도메인 토큰 분리 (read -ra 는 IFS 기반)
IFS=' ' read -ra my_array <<< "$domain"

# 각 도메인 형식 검증 — 잘못된 입력이 certbot 까지 가서 cryptic 오류로 떨어지는 사고 차단
for d in "${my_array[@]}"; do
    if [[ ! "$d" =~ ^[A-Za-z0-9.-]+$ ]]; then
        echo "도메인 형식 오류: '$d' (허용: [A-Za-z0-9.-]+)" >&2
        exit 2
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# (3) 이메일 입력 — Let's Encrypt 가 인증서 만료 임박 경고에 사용.
# ─────────────────────────────────────────────────────────────────────────────
while :
do
    echo -n "Enter the user e-mail > "
    read mail
    echo  "Entered user e-mail: $mail"
    if [[ -z "$mail" ]]; then
        echo "  (값을 입력하세요)"
        continue
    fi
    # 단순 검증 — 'X@Y.Z' 형태인지만 확인 (certbot 자체가 더 엄격하게 거른다)
    if [[ ! "$mail" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
        echo "  (이메일 형식 오류)"
        continue
    fi
    break
done

# ─────────────────────────────────────────────────────────────────────────────
# (4) certbot 인자 합성 — '-d a.com -d www.a.com -d sub.a.com' 형태로 묶는다.
# ─────────────────────────────────────────────────────────────────────────────
delimiter="-d"
domain_string=""
for element in "${my_array[@]}"; do
    domain_string+=" $delimiter $element"
done

# ─────────────────────────────────────────────────────────────────────────────
# (5) 발급 여부 판정 + certbot 실행
#     - 기존 발급된 도메인은 /etc/letsencrypt/live/<primary_domain>/ 에 존재.
#     - 본 스크립트는 초기 발급 전용. 갱신은 nginx Dockerfile 의 cron 이 담당.
# ─────────────────────────────────────────────────────────────────────────────
primary="${my_array[0]}"
LIVE_DIR="/etc/letsencrypt/live/$primary"

if [[ -d "$LIVE_DIR" ]]; then
    echo
    echo "[SKIP] 이미 발급된 인증서가 존재합니다: $LIVE_DIR"
    echo "       - 갱신은 docker/nginx/Dockerfile 에 등록된 cron (매주 월 05:00 UTC) 이 자동 수행합니다."
    echo "       - 강제 재발급이 필요하면 'certbot certonly --force-renewal --webroot ...' 를 직접 실행하세요."
    exit 0
fi

echo
echo "[INFO] certbot 인증서 발급 시작 — primary domain: $primary"
echo "       certbot certonly --non-interactive --agree-tos --email $mail \\"
echo "         --webroot -w /www/$webroot_folder$domain_string"
echo

certbot certonly --non-interactive --agree-tos --email "$mail" \
    --webroot -w "/www/$webroot_folder" $domain_string

echo
echo "[OK] 발급 완료. nginx HTTPS conf 를 생성하고 reload 하세요."
echo "  cd config/web-server/nginx/<stack>/"
echo "  ./nginx_https_conf.sh -w $webroot_folder -p 80 -d $primary -a <appname> -s <svcport> -n <name>"
echo "  docker compose exec webserver nginx -t && docker compose exec webserver nginx -s reload"
echo
echo "참고: 인증서 자동 갱신 cron 은 docker/nginx/Dockerfile 에 이미 등록되어 있으므로"
echo "       본 스크립트가 crontab 을 건드리지 않습니다 (cron 중복/충돌 방지)."
