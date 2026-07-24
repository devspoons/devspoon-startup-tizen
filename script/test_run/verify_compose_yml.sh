#!/usr/bin/env bash
# Validate every stack's docker-compose.yml syntactically and verify the SSL/dhparam volume mount.
set -e

DEVSPOON="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

for stack_dir in "$DEVSPOON"/compose/web_service/*/; do
  stack=$(basename "$stack_dir")
  echo
  echo "=== Validating $stack ==="
  cd "$stack_dir"

  # Make sure .env exists (create from .env-example if missing with safe defaults)
  if [ ! -f .env ]; then
    cp .env-example .env
    sed -i 's|^REDIS_PASSWORD=.*|REDIS_PASSWORD=test-redis-pw|; s|^FLOWER_ID=.*|FLOWER_ID=test|; s|^FLOWER_PWD=.*|FLOWER_PWD=test-pw|' .env
    echo "  (auto-created .env from .env-example)"
  fi

  # docker compose config validates the YAML + env interpolation
  if docker compose config --quiet 2>&1 | grep -qE "."; then
    echo "  [FAIL] docker compose config rejected the YAML"
    docker compose config 2>&1 | tail -5
    FAIL=$((FAIL+1))
    continue
  else
    echo "  [PASS] compose YAML valid"
  fi

  # Verify the dhparam backup mount is present (long-form: source + target on separate lines)
  RESOLVED=$(docker compose config 2>/dev/null)
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

  PASS=$((PASS+1))
done

echo
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
