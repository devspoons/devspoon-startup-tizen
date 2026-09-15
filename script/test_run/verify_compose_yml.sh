#!/usr/bin/env bash
# Validate every stack's docker-compose.yml syntactically and verify the SSL/dhparam volume mount.
set -e

DEVSPOON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0
TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT

for stack_dir in "$DEVSPOON"/compose/web_service/*/; do
  stack=$(basename "$stack_dir")
  echo
  echo "=== Validating $stack ==="
  cd "$stack_dir"

  # 운영 .env 는 읽지도 만들지도 않는다 — .env-example 로 만든 임시 env-file 로만 렌더링한다
  ENVF="$TMPD/$stack.env"
  sed -e 's|^REDIS_PASSWORD=.*|REDIS_PASSWORD=test-redis-pw|; s|^FLOWER_ID=.*|FLOWER_ID=test|; s|^FLOWER_PWD=.*|FLOWER_PWD=test-pw|' \
      -e '/^DJANGO_SECRET_KEY=/d' .env-example > "$ENVF"
  printf 'DJANGO_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" >> "$ENVF"

  # docker compose config validates the YAML + env interpolation
  if docker compose --env-file "$ENVF" config --quiet 2>&1 | grep -qE "."; then
    echo "  [FAIL] docker compose config rejected the YAML"
    docker compose --env-file "$ENVF" config 2>&1 | tail -5
    FAIL=$((FAIL+1))
    continue
  else
    echo "  [PASS] compose YAML valid"
  fi

  # Verify the dhparam backup mount is present (long-form: source + target on separate lines)
  RESOLVED=$(docker compose --env-file "$ENVF" config 2>/dev/null)
  if echo "$RESOLVED" | grep -qE "ssl/dhparam$" && echo "$RESOLVED" | grep -qE "/etc/nginx/dhparam-backup"; then
    echo "  [PASS] ssl/dhparam -> /etc/nginx/dhparam-backup mount present"
  else
    echo "  [FAIL] dhparam backup mount missing in webserver service"
    FAIL=$((FAIL+1))
    continue
  fi

  # Verify the OLD ssl/certs anti-pattern is NOT present
  if echo "$RESOLVED" | grep -qE "ssl/certs$" && echo "$RESOLVED" | grep -qE "/etc/ssl/certs"; then
    echo "  [FAIL] ssl/certs:/etc/ssl/certs anti-pattern still present"
    FAIL=$((FAIL+1))
    continue
  else
    echo "  [PASS] no ssl/certs anti-pattern"
  fi

  # 프로파일 포함 렌더 (celery/redis 프로파일 서비스까지)
  if ! docker compose --env-file "$ENVF" --profile celery --profile redis config -q; then
    echo "  [FAIL] profile(celery,redis) 포함 config 실패"; FAIL=$((FAIL+1)); continue
  fi
  FULL=$(docker compose --env-file "$ENVF" --profile celery --profile redis config --format json)
  # 설정 파일 bind 소스가 실제로 있어야 한다 (없으면 compose 가 빈 디렉터리를 만들어 조용히 깨짐)
  missing=$(echo "$FULL" | jq -r '.services[].volumes[]? | select(.type=="bind") | .source' | grep -E '/(config|script)/' | sort -u | while read -r p; do [ -e "$p" ] || echo "$p"; done)
  if [ -n "$missing" ]; then echo "  [FAIL] bind 소스 없음: $missing"; FAIL=$((FAIL+1)); continue; fi
  # flower 는 127.0.0.1 에만 publish (SEC-09)
  if echo "$FULL" | jq -e '.services.flower' >/dev/null; then
    hip=$(echo "$FULL" | jq -r '[.services.flower.ports[]?.host_ip] | unique | join(",")')
    if [ "$hip" != "127.0.0.1" ]; then echo "  [FAIL] flower host_ip=$hip (127.0.0.1 기대)"; FAIL=$((FAIL+1)); continue; fi
  fi
  echo "  [PASS] profile config · bind 소스 · flower 127.0.0.1"

  PASS=$((PASS+1))
done

echo
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
