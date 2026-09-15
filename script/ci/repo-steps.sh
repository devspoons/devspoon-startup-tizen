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

echo "### 형제 런타임 데이터 폴더는 무시하고 자리표시자 LICENSE 만 추적 (SRV1-SEC-01) ###"
for d in compose/master_service/jenkins_home compose/master_service/pgdata compose/master_service/static compose/master_service/storage compose/project_mng_service/nginx_jenkins/jenkins_home compose/project_mng_service/nginx_openproject/pgdata compose/project_mng_service/nginx_openproject/static compose/project_mng_service/gitolite/storage; do
    if git -C "$ROOT" check-ignore -q --no-index "$d/master.key" && ! git -C "$ROOT" check-ignore -q --no-index "$d/LICENSE"; then
        echo "  [PASS] $d"; else fail "$d — 내용물 미무시 또는 자리표시자 무시"; fi
done

echo "### 공개 예시 비밀값 금지 — OPENPROJECT_SECRET_KEY_BASE 는 빈 값 (SRV1-SEC-02) ###"
for e in compose/master_service/.env-example compose/project_mng_service/nginx_openproject/.env-example; do
    if grep -qE '^OPENPROJECT_SECRET_KEY_BASE=$' "$ROOT/$e"; then echo "  [PASS] $e"; else fail "$e — OPENPROJECT_SECRET_KEY_BASE 예시값 존재"; fi
done

echo "### gitolite sshd 포워딩 차단 (SRV1-SEC-03) ###"
for k in "X11Forwarding no" "AllowTcpForwarding no"; do
    if grep -qE "^$k\$" "$ROOT/docker/gitolite/system/sshd_config"; then echo "  [PASS] $k"; else fail "sshd_config — $k 없음"; fi
done

echo "### master_service python 4조합 — migrate 는 app 서비스만 기동 전 1회, celery·beat 는 app healthy 뒤 (CL-WP2-19-R2) ###"
for s in daphne gunicorn uvicorn uwsgi; do
    f="$ROOT/compose/master_service/docker-compose-$s.yml"
    if [ "$(grep -c 'manage.py migrate --noinput' "$f")" = 1 ] \
        && [ "$(grep -cF '{ [ ! -f manage.py ] || python manage.py migrate --noinput; } && chown -R www-data:www-data /data && ' "$f")" = 1 ] \
        && [ "$(grep -A1 -E "^      ${s}-app:\$" "$f" | grep -c 'condition: service_healthy')" = 3 ]; then
        echo "  [PASS] $s migrate·service_healthy 3곳"; else fail "$s migrate 위치·celery/beat app healthy 의존"; fi
done

echo "### master_service 비밀 키 빈 값·한 줄 생성 안내, 운영 이미지명 격리 IMAGE_NAMESPACE (RV2-S-01, RV2-SEC-03) ###"
e="$ROOT/compose/master_service/.env-example"
for k in $(grep -ohE '\$\{[A-Z_]*(PASSWORD|PWD|SECRET|TOKEN|_KEY)[A-Z_]*:\?' "$ROOT"/compose/master_service/*.yml | sed -E 's/\$\{([A-Z_]+):\?/\1/' | sort -u); do
    if grep -qE "^$k=\$" "$e"; then echo "  [PASS] $k 빈 값"; else fail "master .env-example $k 예시값 존재"; fi
done
if grep -q 'ensure_env_secrets compose/master_service/.env' "$e"; then echo "  [PASS] ensure_env_secrets 안내"; else fail "master .env-example ensure_env_secrets 안내 없음"; fi
if grep -nE '^[[:space:]]+image: devspoon-' "$ROOT"/compose/master_service/*.yml; then fail "고정 devspoon 이미지명"; else echo "  [PASS] 이미지명 IMAGE_NAMESPACE"; fi

echo "### master_service proxy 샘플 — webserver 가 php/proxy/<svc>/ 를 /etc/nginx/proxy.d/<svc>/:ro 로 마운트, 복사본 무시 (SRV1-S-02) ###"
for f in "$ROOT"/compose/master_service/docker-compose-*.yml; do
    for svc in jenkins openproject; do
        if grep -qF -- "- ../../config/web-server/nginx/php/proxy/$svc/:/etc/nginx/proxy.d/$svc/:ro" "$f"; then
            echo "  [PASS] $(basename "$f") $svc"; else fail "$(basename "$f") $svc proxy.d 마운트 없음"; fi
    done
done
if grep -rn '마운트한 conf\.d' "$ROOT"/compose/master_service "$ROOT"/config/web-server/nginx/php/proxy; then fail "conf.d 복사 안내 잔존"; else echo "  [PASS] conf.d 복사 안내 없음"; fi
for svc in jenkins openproject; do
    if git -C "$ROOT" check-ignore -q --no-index "config/web-server/nginx/php/proxy/$svc/${svc}_proxy.conf" \
        && ! git -C "$ROOT" check-ignore -q --no-index "config/web-server/nginx/php/proxy/$svc/default.conf"; then
        echo "  [PASS] $svc 복사본 무시·자리표시자 추적"; else fail "$svc proxy 복사본 ignore 규칙"; fi
done

echo "### master_service / project_mng_service compose config (운영 .env 미사용 — .env-example 로 만든 임시 env-file) ###"
n=0
for f in "$ROOT"/compose/master_service/docker-compose-*.yml "$ROOT"/compose/project_mng_service/{nginx_jenkins,nginx_openproject,gitolite}/docker-compose.yml; do
    d=$(dirname "$f"); n=$((n+1)); envf="$TMPD/$n.env"
    sed -e '/^DJANGO_SECRET_KEY=/d' -e '/^OPENPROJECT_SECRET_KEY_BASE=/d' "$d/.env-example" > "$envf"
    printf 'DJANGO_SECRET_KEY=%s\nOPENPROJECT_SECRET_KEY_BASE=%s\n' "$(openssl rand -hex 32)" "$(openssl rand -hex 64)" >> "$envf"
    docker compose --env-file "$envf" -f "$f" --profile celery --profile redis config -q \
        && echo "  [PASS] $f" || fail "$f"
done
[ "$n" -eq 8 ] || fail "검사 파일 수 $n (기대 8)"
echo "=== RESULT: FAILS=$FAILS ==="
[ "$FAILS" -eq 0 ] || exit 1
