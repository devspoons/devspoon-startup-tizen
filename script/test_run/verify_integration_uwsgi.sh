#!/usr/bin/env bash
# Integration test for nginx_uwsgi stack (uwsgi binary protocol).
set -e

DEVSPOON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK_DIR="$DEVSPOON/compose/web_service/nginx_uwsgi"
NGINX_CFG_DIR="$DEVSPOON/config/web-server/nginx/uwsgi"

cleanup() {
  cd "$STACK_DIR" 2>/dev/null && docker compose down -v --remove-orphans 2>/dev/null || true
  rm -f "$NGINX_CFG_DIR/conf.d/test_uwsgi_ng_http.conf"
}
trap cleanup EXIT

echo "=== Phase 1: prep .env ==="
cd "$STACK_DIR"
[ -f .env ] || cp .env-example .env
sed -i 's|^REDIS_PASSWORD=.*|REDIS_PASSWORD=uwsgi-test-redis-pw|; s|^FLOWER_ID=.*|FLOWER_ID=tester|; s|^FLOWER_PWD=.*|FLOWER_PWD=tester-pw|' .env

echo
echo "=== Phase 2: fix WSL fmask permission ==="
chmod 644 "$STACK_DIR/redis/conf/redis.conf" || true

echo
echo "=== Phase 3a: ensure django_sample secrets.json (test-only) ==="
# settings.py:26 가 secrets.json 을 강제로 읽음 → 부재 시 컨테이너 부팅 실패.
# shellcheck source=../lib/django_secrets.sh
. "$DEVSPOON/script/lib/django_secrets.sh"
ensure_django_secrets "$DEVSPOON"

echo
echo "=== Phase 3: generate HTTP conf for uwsgi (uwsgi_pass protocol) ==="
cd "$NGINX_CFG_DIR"
chmod +x nginx_http_conf.sh
./nginx_http_conf.sh -w django_sample -p 80 -d uwsgi.test -a uwsgi-app -s 8000 -n test 2>&1 | grep -E "생성 완료|Error" || true

echo
echo "=== Phase 4: docker compose up -d ==="
cd "$STACK_DIR"
docker compose up -d 2>&1 | tail -15

sleep 25
echo
echo "=== Phase 5: container state ==="
docker compose ps

echo
echo "=== Phase 6: app logs preview ==="
docker compose logs uwsgi-app 2>&1 | tail -20

echo
echo "=== Phase 7: curl test (Host: uwsgi.test) ==="
RESP=$(curl -s -o /tmp/uwsgi_resp.txt -w "%{http_code}" -H "Host: uwsgi.test" --max-time 10 http://localhost/ 2>&1)
echo "HTTP code: $RESP"
echo "Response head:"
head -3 /tmp/uwsgi_resp.txt 2>/dev/null

echo
echo "=== Phase 8: dhparam SHA verify ==="
HSHA=$(sha256sum "$STACK_DIR/ssl/dhparam/dhparam.pem" 2>/dev/null | awk '{print $1}' || echo MISSING)
CSHA=$(docker compose exec -T webserver sha256sum /etc/nginx/dhparam.pem 2>/dev/null | awk '{print $1}' || echo MISSING)
echo "  host backup sha:  $HSHA"
echo "  container   sha:  $CSHA"
if [ "$HSHA" = "$CSHA" ] && [ "$HSHA" != "MISSING" ]; then
  echo "  [PASS] dhparam consistent"
else
  echo "  [FAIL] dhparam mismatch"
fi

echo
echo "=== Cleanup ==="
docker compose down -v --remove-orphans 2>&1 | tail -3
