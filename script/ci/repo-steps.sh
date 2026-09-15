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

echo "### 형제 런타임 데이터 폴더는 내용물 무시, 빈 자리표시자 .gitkeep 하나만 추적 (SRV1-SEC-01, D-PH) ###"
for d in compose/master_service/jenkins_home compose/master_service/static compose/master_service/storage compose/project_mng_service/nginx_jenkins/jenkins_home compose/project_mng_service/nginx_openproject/static compose/project_mng_service/gitolite/storage; do
    if git -C "$ROOT" check-ignore -q --no-index "$d/master.key" && ! git -C "$ROOT" check-ignore -q --no-index "$d/.gitkeep" \
        && [ "$(git -C "$ROOT" ls-files -- "$d")" = "$d/.gitkeep" ] && [ -f "$ROOT/$d/.gitkeep" ] && [ ! -s "$ROOT/$d/.gitkeep" ]; then
        echo "  [PASS] $d"; else fail "$d — 내용물 미무시·.gitkeep 무시·미추적·비어있지 않음 또는 다른 추적 파일"; fi
done
echo "### OpenProject pgdata 는 폴더 전체 무시·추적 파일 0 — initdb 는 점 파일 하나만 있어도 'not empty' 로 거부 (DEF-PG-01, TC-IN-05-3) ###"
for d in compose/master_service/pgdata compose/project_mng_service/nginx_openproject/pgdata; do
    if git -C "$ROOT" check-ignore -q --no-index "$d/PG_VERSION" && git -C "$ROOT" check-ignore -q --no-index "$d/.gitkeep" \
        && [ -z "$(git -C "$ROOT" ls-files -- "$d")" ]; then
        echo "  [PASS] $d"; else fail "$d — 내용물·.gitkeep 미무시 또는 추적 파일 존재"; fi
done
p=$(git -C "$ROOT" ls-files '*/pgdata/*')
if [ -z "$p" ]; then echo "  [PASS] 추적 pgdata 파일 없음"; else fail "추적 pgdata 파일(첫 기동 initdb 실패):" $p; fi

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
        && [ "$(grep -cF '{ [ ! -f manage.py ] || python manage.py migrate --noinput; } && { [ ! -f prestart.sh ] || bash prestart.sh; } && chown -R www-data:www-data /data && ' "$f")" = 1 ] \
        && [ "$(grep -cx '        lock: ../../www/django_sample' "$f")" = 1 ] \
        && [ "$(grep -A1 -E "^      ${s}-app:\$" "$f" | grep -c 'condition: service_healthy')" = 3 ]; then
        echo "  [PASS] $s migrate→prestart 순서·service_healthy 3곳·lock 빌드 컨텍스트"; else fail "$s migrate 위치·celery/beat app healthy 의존"; fi
done

echo "### master_service 비밀 키 빈 값·한 줄 생성 안내, 운영 이미지명 격리 IMAGE_NAMESPACE (RV2-S-01, RV2-SEC-03) ###"
e="$ROOT/compose/master_service/.env-example"
# <compose 폴더> 의 :? 필수 비밀 키 중 .env-example 에 예시값이 있는 키를 출력.
#   비밀 분류는 ensure_env_secrets(SECRET·PASSWORD·PWD 포함 또는 _KEY_BASE 로 끝남) 와 같아야 하므로 정규식을 따로 두지 않고
#   compose 사본 옆 빈 .env 에 헬퍼를 돌려 추가되는 키를 비밀 키로 쓴다 — *_SSH_KEY 같은 비밀 아닌 경로 변수는 대상 아님
secret_keys_with_example() {
    local w k; w=$(mktemp -d "$TMPD/cls.XXXXXX"); cp "$1"/docker-compose*.yml "$w/"; : > "$w/.env"
    ( . "$ROOT/script/lib/django_secrets.sh"; ensure_env_secrets "$w/.env" ) >/dev/null 2>&1 || echo "<ensure_env_secrets 실패>"
    for k in $(cut -d= -f1 "$w/.env"); do grep -qE "^$k=\$" "$1/.env-example" || echo "$k"; done
}
bad=$(secret_keys_with_example "$ROOT/compose/master_service")
if [ -z "$bad" ]; then echo "  [PASS] master .env-example 비밀 키 빈 값"; else fail "master .env-example 비밀 키 예시값 존재:" $bad; fi
# 자체 검사: 비밀 아닌 필수 경로 변수(FOO_SSH_KEY)는 예시값 허용, 비밀 키(FOO_PASSWORD) 예시값은 검출
fx="$TMPD/secret-fixture"; mkdir -p "$fx"
printf 'services:\n  a:\n    image: busybox\n    environment:\n      K: ${FOO_SSH_KEY:?}\n      P: ${FOO_PASSWORD:?}\n' > "$fx/docker-compose.yml"
printf 'FOO_SSH_KEY=/home/user/.ssh/id_ed25519\nFOO_PASSWORD=\n' > "$fx/.env-example"
if [ -z "$(secret_keys_with_example "$fx")" ]; then echo "  [PASS] 자체 검사 — 비밀 아닌 *_SSH_KEY 경로 변수 예시값 허용"; else fail "자체 검사 — 비밀 아닌 FOO_SSH_KEY 를 비밀로 분류"; fi
printf 'FOO_SSH_KEY=/home/user/.ssh/id_ed25519\nFOO_PASSWORD=example\n' > "$fx/.env-example"
if [ "$(secret_keys_with_example "$fx")" = FOO_PASSWORD ]; then echo "  [PASS] 자체 검사 — 비밀 키 FOO_PASSWORD 예시값 검출"; else fail "자체 검사 — FOO_PASSWORD 예시값 미검출"; fi
if grep -q 'ensure_env_secrets compose/master_service/.env' "$e"; then echo "  [PASS] ensure_env_secrets 안내"; else fail "master .env-example ensure_env_secrets 안내 없음"; fi
if grep -n '외부에 노출' "$e"; then fail "master .env-example flower '외부에 노출' 문구(실제 127.0.0.1 바인드) (SRV1-SEC-05)"; else echo "  [PASS] flower 문구"; fi
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

echo "### ensure_env_secrets — master·단독 openproject 에서 OPENPROJECT_SECRET_KEY_BASE 128 hex, 비밀 아닌 키 불변, 한 줄 안내 (R2S-02) ###"
for d in compose/master_service compose/project_mng_service/nginx_openproject; do
    w="$TMPD/sec-${d##*/}"; mkdir -p "$w"; cp "$ROOT/$d"/docker-compose*.yml "$w/"; cp "$ROOT/$d/.env-example" "$w/.env"
    nonsec() { grep -vE '^[A-Z0-9_]*(SECRET|PASSWORD|PWD)[A-Z0-9_]*=|^[A-Z0-9_]*_KEY_BASE=' "$1" | sha256sum; }
    b=$(nonsec "$w/.env"); ( . "$ROOT/script/lib/django_secrets.sh"; ensure_env_secrets "$w/.env" ) >/dev/null 2>&1
    if grep -qE '^OPENPROJECT_SECRET_KEY_BASE=[0-9a-f]{128}$' "$w/.env" && [ "$(nonsec "$w/.env")" = "$b" ]; then
        echo "  [PASS] $d 헬퍼 실행 → KEY_BASE 128 hex·비밀 아닌 키 불변"; else fail "$d 헬퍼가 OPENPROJECT_SECRET_KEY_BASE 미생성 또는 비밀 아닌 키 변경"; fi
    if grep -q "ensure_env_secrets $d/.env" "$ROOT/$d/.env-example" && ! grep -q 'openssl rand' "$ROOT/$d/.env-example"; then
        echo "  [PASS] $d .env-example 한 줄 안내"; else fail "$d .env-example 직접 생성(openssl) 안내 잔존 또는 헬퍼 안내 없음"; fi
done

echo "### master_service / project_mng_service compose config (운영 .env 미사용 — .env-example 로 만든 임시 env-file) ###"
n=0
for f in "$ROOT"/compose/master_service/docker-compose-*.yml "$ROOT"/compose/project_mng_service/{nginx_jenkins,nginx_openproject,gitolite}/docker-compose.yml; do
    d=$(dirname "$f"); n=$((n+1)); envf="$TMPD/$n.env"
    sed -E '/^(DJANGO_SECRET_KEY|OPENPROJECT_SECRET_KEY_BASE|REDIS_PASSWORD|FLOWER_PWD)=/d' "$d/.env-example" > "$envf" \
        || { fail "$f — $d/.env-example 로 임시 env-file 생성 실패(위 sed 오류)"; continue; }
    printf 'DJANGO_SECRET_KEY=%s\nOPENPROJECT_SECRET_KEY_BASE=%s\nREDIS_PASSWORD=%s\nFLOWER_PWD=%s\n' \
        "$(openssl rand -hex 32)" "$(openssl rand -hex 64)" "$(openssl rand -hex 16)" "$(openssl rand -hex 16)" >> "$envf"
    docker compose --env-file "$envf" -f "$f" --profile celery --profile redis config -q \
        && echo "  [PASS] $f" || fail "$f"
done
[ "$n" -eq 8 ] || fail "검사 파일 수 $n (기대 8)"
echo "### tizen-env 연결 설정 — compose 렌더·정적만, 빌드·기동 없음 (TZ-04·05, D-7, D-T1, D-T9) ###"
TZ="$ROOT/compose/dev_env_service/tizen-env"; GL="$ROOT/compose/project_mng_service/gitolite"
ports() { docker compose --env-file "$1" -f "$2" config --format json | jq -r '.services[].ports[]? | "\(.host_ip // "0.0.0.0"):\(.published)"'; }
if docker compose --env-file "$TZ/.env-example" -f "$TZ/docker-compose.yml" config -q; then echo "  [PASS] tizen-env config"; else fail "tizen-env config"; fi
tz=$(ports "$TZ/.env-example" "$TZ/docker-compose.yml"); gl=$(ports "$GL/.env-example" "$GL/docker-compose.yml")
[ "$tz" = "127.0.0.1:2221" ] && echo "  [PASS] tizen-env SSH $tz" || fail "tizen-env SSH publish=$tz (기대 127.0.0.1:2221)"
dup=$(printf '%s\n%s\n' "$tz" "$gl" | sed 's/.*://' | sort | uniq -d)
[ -z "$dup" ] && echo "  [PASS] 단독 tizen-env ∩ gitolite = ∅" || fail "단독 포트 중복: $dup"
dup=$(ports "$TMPD/3.env" "$ROOT/compose/master_service/docker-compose-php.yml" | sed 's/.*://' | sort | uniq -d)  # 3.env = 위 config 루프의 php 임시 env-file
[ -z "$dup" ] && echo "  [PASS] master php 포트 중복 없음" || fail "master php 포트 중복: $dup"
if TIZEN_SSH_KEY= docker compose --env-file "$TZ/.env-example" -f "$TZ/docker-compose.yml" config -q 2>/dev/null; then
    fail "TIZEN_SSH_KEY 빈 값인데 config 성공 (fail-fast 없음)"; else echo "  [PASS] TIZEN_SSH_KEY 필수"; fi
for k in "PermitRootLogin prohibit-password" "X11Forwarding no" "AllowTcpForwarding no"; do
    if grep -qx "$k" "$ROOT/docker/tizen-env/system/sshd_config"; then echo "  [PASS] tizen-env $k"; else fail "tizen-env sshd_config — $k 없음"; fi
done
if grep -q 'id_rsa' "$ROOT/docker/tizen-env/Dockerfile"; then fail "Dockerfile 이 id_rsa 를 이미지에 넣음"; else echo "  [PASS] Dockerfile id_rsa 없음"; fi
echo "=== RESULT: FAILS=$FAILS ==="
[ "$FAILS" -eq 0 ] || exit 1
