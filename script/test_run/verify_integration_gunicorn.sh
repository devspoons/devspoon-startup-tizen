#!/usr/bin/env bash
# Integration test for nginx_gunicorn stack
set +e

DEVSPOON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK_DIR="$DEVSPOON/compose/web_service/nginx_gunicorn"
NGINX_CFG_DIR="$DEVSPOON/config/web-server/nginx/gunicorn"

cleanup() {
  echo
  echo "=== cleanup ==="
  cd "$STACK_DIR" 2>/dev/null && docker compose down -v --remove-orphans 2>&1 | tail -5 || true
}
trap cleanup EXIT

echo "=== Phase 1: prep .env ==="
cd "$STACK_DIR"
[ -f .env ] || cp .env-example .env
sed -i 's|^REDIS_PASSWORD=.*|REDIS_PASSWORD=gunicorn-test-redis-pw|; s|^FLOWER_ID=.*|FLOWER_ID=tester|; s|^FLOWER_PWD=.*|FLOWER_PWD=tester-pw|' .env
grep -E '^(REDIS_PASSWORD|FLOWER_ID|FLOWER_PWD|PROJECT_DIR|PROJECT_NAME)' .env

echo
echo "=== Phase 2: fix WSL fmask permission ==="
chmod 644 "$STACK_DIR/redis/conf/redis.conf" 2>/dev/null || true
chmod 644 "$DEVSPOON/config/app-server/gunicorn/"*.py 2>/dev/null || true
chmod 644 "$NGINX_CFG_DIR/nginx_conf/nginx.conf" 2>/dev/null || true
chmod 644 "$NGINX_CFG_DIR/proxy_params/proxy_params" 2>/dev/null || true

echo
echo "=== Phase 3a: verify django_sample conf present ==="
# Sample conf 는 영구 .conf 파일로 트래킹되어 있어 nginx 컨테이너 시작 시 자동 로드된다.
# (과거 .example → .conf cp 단계는 conf.d 샘플 명명 정책 통일로 제거됨)
ls "$NGINX_CFG_DIR/conf.d/"

echo
echo "=== Phase 3b: ensure django_sample secrets.json (test-only) ==="
# settings.py:26 가 secrets.json 을 강제로 읽음 → 부재 시 ImportError.
# 50f7505 commit 후 추적 해제됐으므로 새 환경에서는 운영자가 직접 만들어야 한다.
# 테스트에서는 secrets.json.example 로부터 자동 생성 (공유 헬퍼).
# shellcheck source=../lib/django_secrets.sh
. "$DEVSPOON/script/lib/django_secrets.sh"
ensure_django_secrets "$DEVSPOON"

echo
echo "=== Phase 4: docker compose up -d (without celery profile) ==="
cd "$STACK_DIR"
docker compose up -d --build 2>&1 | tail -20

echo
echo "=== Phase 5: wait for healthcheck (60s with progress) ==="
for i in 1 2 3 4 5 6; do
  sleep 10
  state=$(docker compose ps --format json 2>/dev/null | grep -o '"State":"[^"]*"' | sort -u | tr '\n' ' ')
  echo "  [$((i*10))s] states: $state"
done

echo
echo "=== Phase 6: container state ==="
docker compose ps

echo
echo "=== Phase 7: logs preview ==="
echo "--- gunicorn-app logs ---"
docker compose logs gunicorn-app 2>&1 | tail -20
echo
echo "--- webserver logs ---"
docker compose logs webserver 2>&1 | tail -10
echo
echo "--- redis logs (간단) ---"
docker compose logs redis 2>&1 | tail -5

echo
echo "=== Phase 8: curl test (Host: localhost) ==="
RESP=$(curl -s -o /tmp/gunicorn_resp.html -w "HTTP=%{http_code} TIME=%{time_total}s SIZE=%{size_download}" -H "Host: localhost" --max-time 15 http://localhost/ 2>&1)
echo "$RESP"
echo
echo "Response head (5 lines):"
head -5 /tmp/gunicorn_resp.html 2>/dev/null
echo
echo "Gzip check (Accept-Encoding: gzip):"
curl -s -I -H "Accept-Encoding: gzip" --max-time 5 -H "Host: localhost" http://localhost/ 2>&1 | head -10

echo
echo "=== Phase 9: dhparam check ==="
ls -la "$STACK_DIR/ssl/dhparam/" 2>&1
HSHA=$(sha256sum "$STACK_DIR/ssl/dhparam/dhparam.pem" 2>/dev/null | awk '{print $1}' || echo MISSING)
echo "dhparam.pem sha256: $HSHA"

echo
echo "=== Phase 10: chown verification (Phase B+C 적용 검증) ==="
docker compose exec -T gunicorn-app ps -ef 2>&1 | grep -E "gunicorn|UID" | head -5

echo
echo "=== DONE ==="
