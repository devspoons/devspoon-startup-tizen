#!/usr/bin/env bash
# Integration test for nginx_php stack
set +e

DEVSPOON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK_DIR="$DEVSPOON/compose/web_service/nginx_php"
NGINX_CFG_DIR="$DEVSPOON/config/web-server/nginx/php"

cleanup() {
  echo
  echo "=== cleanup ==="
  cd "$STACK_DIR" 2>/dev/null && docker compose down -v --remove-orphans 2>&1 | tail -5 || true
  rm -f "$DEVSPOON/config/app-server/php-8.4/pool.d/localhost.conf"
}
trap cleanup EXIT

echo "=== Phase 1: prep .env ==="
cd "$STACK_DIR"
[ -f .env ] || cp .env-example .env
sed -i 's|^REDIS_PASSWORD=.*|REDIS_PASSWORD=php84-test-redis-pw|; s|^FLOWER_ID=.*|FLOWER_ID=tester|; s|^FLOWER_PWD=.*|FLOWER_PWD=tester-pw|' .env
grep -E '^(REDIS_PASSWORD|PROJECT|PORT)' .env

echo
echo "=== Phase 2: WSL fmask ==="
chmod 644 "$STACK_DIR/redis/conf/redis.conf" 2>/dev/null || true
chmod 644 "$DEVSPOON/config/app-server/php-8.4/php_ini/php.ini" 2>/dev/null || true

echo
echo "=== Phase 3a: verify nginx php sample conf present ==="
# Sample conf 는 영구 .conf 파일로 트래킹되어 있어 nginx 컨테이너 시작 시 자동 로드된다.
# (과거 .example → .conf cp 단계는 conf.d 샘플 명명 정책 통일로 제거됨)
ls "$NGINX_CFG_DIR/conf.d/"

echo
echo "=== Phase 3b: activate php-fpm pool (placeholder 치환) ==="
POOL_DIR="$DEVSPOON/config/app-server/php-8.4/pool.d"
sed -e 's|\[domain\]|[localhost]|g' -e 's|:portnumber|:9000|g' \
  "$POOL_DIR/sample_php.conf.example" > "$POOL_DIR/localhost.conf"
echo "  created: localhost.conf"
grep -E "^\[|^listen|^user|^group" "$POOL_DIR/localhost.conf" | head -5

echo
echo "=== Phase 4: docker compose up -d ==="
cd "$STACK_DIR"
docker compose up -d --build 2>&1 | tail -15

echo
echo "=== Phase 5: wait for healthcheck (45s) ==="
for i in 1 2 3 4 5; do
  sleep 9
  state=$(docker compose ps --format json 2>/dev/null | grep -o '"State":"[^"]*"' | sort -u | tr '\n' ' ')
  echo "  [$((i*9))s] states: $state"
done

echo
echo "=== Phase 6: container state ==="
docker compose ps

echo
echo "=== Phase 7: logs preview ==="
echo "--- php-app logs ---"
docker compose logs php-app 2>&1 | tail -15
echo
echo "--- webserver logs ---"
docker compose logs webserver 2>&1 | tail -10

echo
echo "=== Phase 8: curl test ==="
RESP=$(curl -s -o /tmp/php84_resp.html -w "HTTP=%{http_code} TIME=%{time_total}s SIZE=%{size_download}" -H "Host: localhost" --max-time 15 http://localhost/ 2>&1)
echo "$RESP"
echo
echo "Response head (10 lines):"
head -10 /tmp/php84_resp.html 2>/dev/null
echo
echo "PHP version 확인 (response 안에서):"
grep -o "PHP Version[^<]*" /tmp/php84_resp.html 2>/dev/null | head -3
echo
echo "Gzip check:"
curl -s -I -H "Accept-Encoding: gzip" --max-time 5 -H "Host: localhost" http://localhost/ 2>&1 | head -10

echo
echo "=== Phase 9: dhparam ==="
HSHA=$(sha256sum "$STACK_DIR/ssl/dhparam/dhparam.pem" 2>/dev/null | awk '{print $1}' || echo MISSING)
echo "dhparam sha256: $HSHA"

echo
echo "=== Phase 10: php process ==="
docker compose exec -T php-app bash -c "ps -ef 2>&1 | grep -E 'php-fpm|UID' | head -5"

echo
echo "=== DONE ==="
