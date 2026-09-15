#!/usr/bin/env bash
# 저장소 고유 검사 — 형제 3곳이 같은 경로·같은 run-ci 호출 줄을 쓰고 내용만 저장소별로 둔다.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILS=0
fail() { echo "  [FAIL] $*"; FAILS=$((FAILS+1)); }

echo "### master_service poetry 잔재 ###"
if grep -rn 'poetry' "$ROOT/compose/master_service" --include='*.yml'; then fail "poetry 잔재"; else echo "  [PASS] 없음"; fi

echo "### master_service / project_mng_service compose config ###"
n=0
for f in "$ROOT"/compose/master_service/docker-compose-*.yml "$ROOT"/compose/project_mng_service/{nginx_jenkins,nginx_openproject,gitolite}/docker-compose.yml; do
    d=$(dirname "$f"); n=$((n+1))
    docker compose --env-file "$d/.env-example" -f "$f" --profile celery --profile redis config -q \
        && echo "  [PASS] $f" || fail "$f"
done
[ "$n" -eq 8 ] || fail "검사 파일 수 $n (기대 8)"
echo "=== RESULT: FAILS=$FAILS ==="
[ "$FAILS" -eq 0 ] || exit 1
