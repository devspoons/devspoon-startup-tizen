#!/usr/bin/env bash
# 저장소 고유 검사 — 형제 3곳이 같은 경로·같은 run-ci 호출 줄을 쓰고 내용만 저장소별로 둔다.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILS=0
fail() { echo "  [FAIL] $*"; FAILS=$((FAILS+1)); }
TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT

echo "### master_service poetry 잔재·호스트 소스 트리 chown·가드 없는 PROJECT_DIR ###"
if grep -rn 'poetry' "$ROOT/compose/master_service" --include='*.yml'; then fail "poetry 잔재"; else echo "  [PASS] poetry 없음"; fi
if grep -nE 'chown[^"]*/www/' "$ROOT"/compose/master_service/*.yml; then fail "/www chown 잔재"; else echo "  [PASS] /www chown 없음"; fi
if grep -nF '${PROJECT_DIR}' "$ROOT"/compose/master_service/*.yml; then fail "가드 없는 PROJECT_DIR"; else echo "  [PASS] PROJECT_DIR 가드"; fi

echo "### master_service / project_mng_service compose config (운영 .env 미사용 — .env-example 로 만든 임시 env-file) ###"
n=0
for f in "$ROOT"/compose/master_service/docker-compose-*.yml "$ROOT"/compose/project_mng_service/{nginx_jenkins,nginx_openproject,gitolite}/docker-compose.yml; do
    d=$(dirname "$f"); n=$((n+1)); envf="$TMPD/$n.env"
    sed -e '/^DJANGO_SECRET_KEY=/d' "$d/.env-example" > "$envf"
    printf 'DJANGO_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" >> "$envf"
    docker compose --env-file "$envf" -f "$f" --profile celery --profile redis config -q \
        && echo "  [PASS] $f" || fail "$f"
done
[ "$n" -eq 8 ] || fail "검사 파일 수 $n (기대 8)"
echo "=== RESULT: FAILS=$FAILS ==="
[ "$FAILS" -eq 0 ] || exit 1
