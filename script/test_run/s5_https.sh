#!/usr/bin/env bash
# Section 5 HTTPS verification on the currently running stack
set +e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK_DIR="$1"        # nginx_php / nginx_gunicorn / nginx_uvicorn / nginx_uwsgi / nginx_daphne
STACK="$2"            # php / gunicorn etc.
WEBROOT="$3"          # php_sample / django_sample
APPNAME="$4"          # php-app / gunicorn-app
SPORT="$5"            # 9000 / 8000
# 출고 http 샘플(server_name localhost)과 겹치지 않는 테스트 도메인 — 운영 흐름("HTTPS 로 전환한 도메인의 HTTP conf 는 제거")을 재현
DOM="${S5_DOMAIN:-s5-https.test}"
S5_WAIT="${S5_WAIT:-20}"   # reload 후 새 워커가 https server 블록을 서빙할 때까지 최대 대기(초)

NGINX_DIR="$ROOT/config/web-server/nginx/$STACK"

cd "$NGINX_DIR" || { echo "FAIL cd to $NGINX_DIR"; exit 1; }
# 생성한 https conf 는 종료 시 정리 — 추적 트리에 잔여 파일을 남기지 않는다
trap 'rm -f "$NGINX_DIR/conf.d/s5_${STACK}_ng_https.conf"; (cd "$ROOT/compose/web_service/$STACK_DIR" && docker compose exec -T webserver sh -c "rm -rf /etc/letsencrypt/live/$DOM; nginx -s reload" >/dev/null 2>&1)' EXIT

# 5-A: generate https conf for the test domain
# nginx_https_conf.sh 의 SUFFIX 는 "_${STACK}_ng_https" — 결과 파일명: <NAME>_<STACK>_ng_https.conf
echo "===== 5-A generate HTTPS conf ($DOM) for $STACK ====="
./nginx_https_conf.sh -w "$WEBROOT" -p 80 -d "$DOM" -a "$APPNAME" -s "$SPORT" -n s5 2>&1 | tail -5
ls "conf.d/s5_${STACK}_ng_https.conf"

cd "$ROOT/compose/web_service/$STACK_DIR" || { echo "FAIL cd"; exit 1; }

# 5.0: generate self-signed cert and reload nginx
echo "===== 5.0 self-signed cert + nginx -t + reload ====="
docker compose exec -T webserver sh -c '
set -e
for p in $(grep -hE "^[[:space:]]*ssl_certificate[[:space:]]" /etc/nginx/conf.d/*.conf | awk "{print \$2}" | sed "s/;//" | sort -u); do
    d=$(dirname "$p")
    cn=$(basename "$d")
    mkdir -p "$d"
    if [ ! -f "$p" ]; then
        openssl req -x509 -nodes -newkey rsa:2048 -days 1 -subj "/CN=$cn" -keyout "$d/privkey.pem" -out "$d/fullchain.pem" 2>/dev/null
    fi
    cp -f "$d/fullchain.pem" "$d/chain.pem"
    # dhparam(ssl_dhparam)은 이미지에 구워진 /etc/nginx/dhparam.pem 사용 → 테스트에서 별도 생성 불필요
done
nginx -t && nginx -s reload
' 2>&1 | tail -20

# reload 는 비동기 — 새 워커가 https server 블록을 서빙할 때까지 대기 (reload 직후 측정하면 거짓 FAIL)
echo "===== 5-B wait for HTTPS ($DOM, 최대 ${S5_WAIT}s) ====="
ready=0
for _ in $(seq "$S5_WAIT"); do
    if curl -sIk --max-time 3 --resolve "$DOM:443:127.0.0.1" "https://$DOM/" 2>/dev/null | grep -qi '^strict-transport-security'; then ready=1; break; fi
    sleep 1
done
echo "  ready=$ready"

# 각 검사는 출력만 하지 않고 명시적으로 pass/fail 을 판정한다 (과거: grep 출력만 → 자동 게이트로 무의미).
FAILS=0

# 5.1 TLS handshake — 협상 프로토콜·암호군. -brief 출력(Protocol version·Ciphersuite)은 OpenSSL 1.1·3 공통
#     (기본 출력의 SSL-Session `Protocol  :` 줄은 OpenSSL 3 TLS1.3 에서 나오지 않는다). 연결 실패 시 두 줄 모두 없음.
echo "===== 5.1 TLS handshake ====="
tls=$(openssl s_client -brief -connect 127.0.0.1:443 -servername "$DOM" </dev/null 2>&1 | grep -E "^(Protocol version|Ciphersuite):")
echo "$tls"
if echo "$tls" | grep -qE '^Protocol version: *TLSv1\.[23]$' && echo "$tls" | grep -qE '^Ciphersuite: *[A-Z0-9_-]+$'; then
    echo "  PASS 5.1"
else
    echo "  FAIL 5.1 (no TLS handshake)"; FAILS=$((FAILS+1))
fi

# 5.2 HSTS (use URL with hostname so SNI is set correctly)
echo "===== 5.2 HSTS ====="
hsts=$(curl -sIk --resolve "$DOM:443:127.0.0.1" "https://$DOM/" 2>/dev/null | grep -i strict-transport-security)
echo "$hsts"
echo "$hsts" | grep -qiE "max-age=[0-9]+" && { echo "  PASS 5.2"; } || { echo "  FAIL 5.2 (no HSTS max-age)"; FAILS=$((FAILS+1)); }

# 5.3 80->443 redirect
echo "===== 5.3 80->443 redirect ====="
redir=$(curl -sI -H "Host: $DOM" http://127.0.0.1/foo 2>/dev/null)
echo "$redir" | grep -E "(HTTP/.*30[12]|Location:)"
if echo "$redir" | grep -qE "HTTP/.* 30[12]" && echo "$redir" | grep -qiE "^location: *https://"; then
    echo "  PASS 5.3"
else
    echo "  FAIL 5.3 (no 301/302 -> https)"; FAILS=$((FAILS+1))
fi

# 5.4 unknown SNI — 핸드셰이크가 거부되어야 한다 (ssl_reject_handshake). curl 은 non-zero 로 실패해야 정상.
echo "===== 5.4 unknown SNI rejection ====="
sni_out=$(curl -k --resolve evil.example:443:127.0.0.1 https://evil.example/ 2>&1); sni_ec=$?
echo "$sni_out" | head -3
if [ "$sni_ec" -ne 0 ]; then
    echo "  PASS 5.4 (rejected, curl exit=$sni_ec)"
else
    echo "  FAIL 5.4 (unknown SNI accepted)"; FAILS=$((FAILS+1))
fi

echo
echo "===== 5 FAILS=$FAILS ====="
[ "$FAILS" -eq 0 ]
exit $?
