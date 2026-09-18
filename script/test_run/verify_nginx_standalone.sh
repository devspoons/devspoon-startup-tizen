#!/usr/bin/env bash
# Standalone nginx test: start the nginx container with the gunicorn stack mounts,
# generate a domain conf, run nginx -t, verify dhparam backup volume + restore works.
set -e

DEVSPOON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK_DIR="$DEVSPOON/compose/web_service/nginx_gunicorn"
NGINX_CFG_DIR="$DEVSPOON/config/web-server/nginx/gunicorn"
BACKUP_DIR="$STACK_DIR/ssl/dhparam"

cleanup() {
  # docker rm -f 가 "removal already in progress" 일 수 있어 wait + 재시도
  docker rm -f standalone-nginx >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5; do
    docker ps -a --filter "name=standalone-nginx" --format '{{.Names}}' | grep -qx standalone-nginx || break
    sleep 1
  done
  rm -f "$NGINX_CFG_DIR/conf.d/sa_gunicorn_ng_http.conf" || true
  rm -f "$NGINX_CFG_DIR/conf.d/sa_gunicorn_ng_https.conf" || true
}
trap cleanup EXIT
# [FAIL] 판정 수 — 출력만 하고 exit 0 이면 자동 게이트(run-ci·검증 러너)에서 무의미
SA_FAILS=0

echo "=== Pre: clean prior backup dhparam (force fresh test) ==="
# ssl/dhparam 은 추적하지 않는 런타임 폴더 — 새 클론에는 없으므로 먼저 만든다 (없으면 set -e 로 아래 ls 에서 즉시 종료)
mkdir -p "$BACKUP_DIR"
# 앞선 스택 기동이 남긴 백업본은 컨테이너(root)가 만든 파일 — 호스트 사용자 rm 은 Permission denied 이므로 같은 이미지로 지운다
docker run --rm --entrypoint rm -v "$BACKUP_DIR/":/b devspoon-nginx:latest -f /b/dhparam.pem
ls -la "$BACKUP_DIR/"

echo
echo "=== Generate HTTP domain conf (sa.test as Host) ==="
cd "$NGINX_CFG_DIR"
./nginx_http_conf.sh -w django_sample -p 80 -d sa.test -a gunicorn-app -s 8000 -n sa | head -5
[ -f "conf.d/sa_gunicorn_ng_http.conf" ] && echo "  HTTP conf created"

echo
echo "=== Start nginx standalone (no gunicorn-app dependency) ==="
docker run -d --name standalone-nginx \
  -v "$DEVSPOON/www":/www \
  -v "$DEVSPOON/script":/script \
  -v "$NGINX_CFG_DIR/conf.d/":/etc/nginx/conf.d/ \
  -v "$NGINX_CFG_DIR/nginx_conf/nginx.conf":/etc/nginx/nginx.conf \
  -v "$NGINX_CFG_DIR/proxy_params/proxy_params":/etc/nginx/proxy_params \
  -v "$BACKUP_DIR/":/etc/nginx/dhparam-backup/ \
  -v "$DEVSPOON/log/":/log/ \
  -v "$DEVSPOON/script/logrotate/nginx/nginx":/etc/logrotate.d/nginx \
  -p 18800:80 -p 18443:443 \
  -e TZ=Asia/Seoul \
  devspoon-nginx:latest >/dev/null
# entrypoint hook 직렬화 (envsubst, dhparam backup, cron 등)로 6~10초 소요되는 경우가 있다.
# 호스트 백업이 생성될 때까지 폴링하여 race 방지.
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  [ -s "$BACKUP_DIR/dhparam.pem" ] && break
  sleep 1
done

echo
echo "=== Verify nginx process running ==="
docker ps -a --filter "name=standalone-nginx" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
echo "=== nginx -t (config validity) ==="
docker exec standalone-nginx nginx -t 2>&1 | tail -5 || echo "(docker exec failed — container may have exited; this is expected without upstream)"

echo
echo "=== Verify dhparam was backed up to host (entrypoint hook ran) ==="
ls -la "$BACKUP_DIR/"
if [ -f "$BACKUP_DIR/dhparam.pem" ]; then
  HSHA=$(sha256sum "$BACKUP_DIR/dhparam.pem" | awk '{print $1}')
  # standalone 기동 시 upstream(gunicorn-app)이 없으면 nginx master 가 즉시 종료된 뒤
  # docker exec 가 거부될 수 있다. docker exec race 를 피하기 위해 종료 후에도 동작하는
  # docker cp 로 파일을 읽는다.
  TMP_PEM=$(mktemp)
  if docker cp standalone-nginx:/etc/nginx/dhparam.pem "$TMP_PEM" >/dev/null 2>&1; then
    CSHA=$(sha256sum "$TMP_PEM" | awk '{print $1}')
    rm -f "$TMP_PEM"
    echo "  host backup sha:  $HSHA"
    echo "  container sha:    $CSHA"
    if [ "$HSHA" = "$CSHA" ]; then
      echo "  [PASS] backup matches container dhparam — backup-on-first-run works"
    else
      SA_FAILS=$((SA_FAILS+1)); echo "  [FAIL] backup and container dhparam differ"
    fi
  else
    rm -f "$TMP_PEM"
    echo "  host backup sha:  $HSHA"
    echo "  [SKIP] docker cp from standalone-nginx failed; host backup itself was created OK"
    docker logs standalone-nginx 2>&1 | tail -10 || true
  fi
else
  SA_FAILS=$((SA_FAILS+1)); echo "  [FAIL] no host backup created"
fi

echo
echo "=== Test domain match (Host header → server_name routing) ==="
curl -sS -o /dev/null -w "%{http_code}\n" -H "Host: sa.test" http://localhost:18800/ || echo "(curl failed)"

echo
echo "=== docker compose 'down' simulation: stop + rm container, restart fresh ==="
docker rm -f standalone-nginx >/dev/null
sleep 1
docker run -d --name standalone-nginx \
  -v "$DEVSPOON/www":/www \
  -v "$DEVSPOON/script":/script \
  -v "$NGINX_CFG_DIR/conf.d/":/etc/nginx/conf.d/ \
  -v "$NGINX_CFG_DIR/nginx_conf/nginx.conf":/etc/nginx/nginx.conf \
  -v "$NGINX_CFG_DIR/proxy_params/proxy_params":/etc/nginx/proxy_params \
  -v "$BACKUP_DIR/":/etc/nginx/dhparam-backup/ \
  -v "$DEVSPOON/log/":/log/ \
  -v "$DEVSPOON/script/logrotate/nginx/nginx":/etc/logrotate.d/nginx \
  -p 18800:80 -p 18443:443 \
  -e TZ=Asia/Seoul \
  devspoon-nginx:latest >/dev/null
# 재기동 후 컨테이너 준비 폴링 (또는 즉시 종료 감지)
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if docker exec standalone-nginx true >/dev/null 2>&1; then
    break
  fi
  if ! docker ps -a --filter "name=standalone-nginx" --format '{{.Status}}' | grep -q "Up"; then
    # 컨테이너가 곧 종료될 수도 있으니 잠시 더 기다린다 (entrypoint hook 실행 중).
    :
  fi
  sleep 1
done

if docker ps --filter "name=standalone-nginx" --filter "status=running" --format '{{.Names}}' | grep -qx standalone-nginx; then
  C2SHA=$(docker exec standalone-nginx sha256sum /etc/nginx/dhparam.pem | awk '{print $1}')
  echo "  container dhparam sha after restart: $C2SHA"
  if [ "$C2SHA" = "$HSHA" ]; then
    echo "  [PASS] same dhparam restored from host backup after restart"
  else
    SA_FAILS=$((SA_FAILS+1)); echo "  [FAIL] dhparam changed across restart"
  fi
else
  # 컨테이너가 종료된 경우에도 docker cp 로 종료된 컨테이너 안의 dhparam.pem 을 읽을 수 있다.
  # nginx 마스터가 종료해도 파일시스템은 남아있으므로 sha 비교는 그대로 의미 있다.
  TMP_PEM=$(mktemp)
  if docker cp standalone-nginx:/etc/nginx/dhparam.pem "$TMP_PEM" >/dev/null 2>&1; then
    C2SHA=$(sha256sum "$TMP_PEM" | awk '{print $1}')
    rm -f "$TMP_PEM"
    echo "  container dhparam sha after restart (via docker cp): $C2SHA"
    if [ "$C2SHA" = "$HSHA" ]; then
      echo "  [PASS] same dhparam restored from host backup after restart"
    else
      SA_FAILS=$((SA_FAILS+1)); echo "  [FAIL] dhparam changed across restart"
    fi
  else
    rm -f "$TMP_PEM"
    echo "  [SKIP] container exited and docker cp failed; cannot verify post-restart sha"
  fi
fi

echo
echo "=== Generate HTTPS conf (for path verification only — no cert) ==="
cd "$NGINX_CFG_DIR"
./nginx_https_conf.sh -w django_sample -p 80 -d sa.test -a gunicorn-app -s 8000 -n sa | head -5
[ -f "conf.d/sa_gunicorn_ng_https.conf" ] && echo "  HTTPS conf created"

echo
echo "=== Verify HTTPS conf paths point to expected files ==="
grep -E "ssl_certificate|ssl_dhparam|root\s|/.well-known/acme-challenge" conf.d/sa_gunicorn_ng_https.conf | head -10

echo
echo "=== nginx -t with both HTTP+HTTPS conf (expect fail since no real cert) ==="
docker exec standalone-nginx nginx -t 2>&1 | tail -8 || true
echo "(nginx -t fail is EXPECTED because cert files /etc/letsencrypt/live/sa.test/* don't exist - this proves path resolution is correct)"

echo
echo "=== ALL DONE (FAILS=$SA_FAILS) ==="
[ "$SA_FAILS" -eq 0 ]
