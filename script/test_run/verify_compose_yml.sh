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

  # compose 가 :? 로 요구하는 키는 하나만 비어도 거부돼야 한다 — 다른 키가 먼저 거부해 가려지는 회귀 방지
  req=$(grep -hvE '^[[:space:]]*#' docker-compose*.yml | grep -oE '\$\{[A-Z0-9_]+:\?' | sed 's/^\${//; s/:?$//' | sort -u)
  bad=""
  # .env-example 에서 빈 값인 키(비밀, s6 6.29)는 모두 :? 이어야 한다 — compose 에서 :? 가 빠진 회귀는 위 수집에서 사라지므로 따로 대조
  for k in $(grep -oE '^[A-Z0-9_]+=$' .env-example | tr -d =); do
    grep -qx "$k" <<<"$req" || bad="$bad $k(:? 없음)"
  done
  for k in $req; do
    { grep -v "^$k=" "$ENVF"; echo "$k="; } > "$TMPD/$stack.one.env"
    if out=$(docker compose --env-file "$TMPD/$stack.one.env" --profile celery --profile redis config -q 2>&1); then bad="$bad $k(rc0)"
    elif [[ "$out" != *"$k"* ]]; then bad="$bad $k(메시지)"; fi
  done
  if [ -n "$req" ] && [ -z "$bad" ]; then
    echo "  [PASS] :? 필수 키 개별 빈 값 거부 ($(wc -w <<<"$req")개)"
  else
    echo "  [FAIL] :? 필수 키 개별 빈 값 거부 —${bad:- :? 키 없음}"; FAIL=$((FAIL+1)); continue
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
