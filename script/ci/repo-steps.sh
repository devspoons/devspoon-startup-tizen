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
for d in compose/master_service/jenkins_home compose/project_mng_service/nginx_jenkins/jenkins_home; do
    if git -C "$ROOT" check-ignore -q --no-index "$d/master.key" && ! git -C "$ROOT" check-ignore -q --no-index "$d/.gitkeep" \
        && [ "$(git -C "$ROOT" ls-files -- "$d")" = "$d/.gitkeep" ] && [ -f "$ROOT/$d/.gitkeep" ] && [ ! -s "$ROOT/$d/.gitkeep" ]; then
        echo "  [PASS] $d"; else fail "$d — 내용물 미무시·.gitkeep 무시·미추적·비어있지 않음 또는 다른 추적 파일"; fi
done
echo "### Plane·Gitea 데이터는 named volume — 호스트 데이터 폴더·추적 파일 0 (LIVE-R3-PLANE-VOL) ###"
if [ -z "$(git -C "$ROOT" ls-files '*/pgdata/*')" ] && [ ! -e "$ROOT/compose/master_service/pgdata" ]; then
    echo "  [PASS] pgdata 호스트 폴더·추적 파일 없음"; else fail "pgdata 호스트 폴더 또는 추적 파일 잔존(Plane 은 named volume 사용)"; fi
for y in "$ROOT"/compose/common/plane-services.yml "$ROOT"/compose/common/gitea-service.yml; do
    if grep -qE '^\s+- \./' "$y"; then fail "${y#$ROOT/} — 호스트 bind mount 사용(컨테이너 uid 불일치 위험)"; else echo "  [PASS] ${y#$ROOT/} named volume 전용"; fi
done

echo "### 공개 예시 비밀값 금지 — Plane 비밀 키는 빈 값 (SRV1-SEC-02) ###"
for e in compose/master_service/.env-example compose/project_mng_service/nginx_plane/.env-example; do
    miss=""
    for k in PLANE_SECRET_KEY PLANE_LIVE_SERVER_SECRET_KEY PLANE_DB_PASSWORD PLANE_MQ_PASSWORD PLANE_MINIO_PASSWORD; do
        grep -qE "^$k=\$" "$ROOT/$e" || miss="$miss $k"
    done
    [ -z "$miss" ] && echo "  [PASS] $e" || fail "$e — 빈 값이 아닌 비밀 키:$miss"
done

# Match 앞 유효 줄(대소문자 무시)이 전부 기대값 — sshd 가 쓰는 첫 값·마지막 값 모두 보장, 줄이 없어도 FAIL
echo "### Gitea 설정 — 내장 SSH·설치잠금·데이터 named volume·SSH 포트 표기 (LIVE-R3-GITEA) ###"
g="$ROOT/compose/common/gitea-service.yml"
for kv in 'GITEA__security__INSTALL_LOCK: "true"' 'USER_UID: "1000"' 'gitea-data:/data'; do
    grep -qF "$kv" "$g" && echo "  [PASS] gitea $kv" || fail "gitea-service.yml — $kv 없음"
done
# 클론 URL 에 찍히는 SSH_PORT 와 호스트 게시 포트가 같은 변수를 써야 한다
if grep -qF 'GITEA__server__SSH_PORT: ${GITEA_SSH_PORT:-2222}' "$g" && grep -qF '${GITEA_SSH_PORT:-2222}:22' "$g"; then
    echo "  [PASS] gitea SSH_PORT 와 게시 포트 동일 변수"; else fail "gitea SSH_PORT·게시 포트 불일치(클론 URL 이 잘못 안내됨)"; fi
# 이미지의 OpenSSH 가 컨테이너 22 를 쓰므로 내장 SSH 서버를 같은 포트로 켜면 기동 실패한다
if grep -v '^[[:space:]]*#' "$g" | grep -q 'START_SSH_SERVER'; then fail "gitea START_SSH_SERVER 설정(이미지 OpenSSH 와 22 충돌)"; else echo "  [PASS] gitea 내장 SSH 서버 미사용(이미지 OpenSSH)"; fi
# 설정·이미지·경로에 gitolite 가 남아 있으면 실패(주석 안의 이력 설명은 허용)
gl=$(grep -rn --exclude-dir=.git -i 'gitolite' "$ROOT/compose" "$ROOT/docker" "$ROOT/config" 2>/dev/null | grep -vE ':[[:space:]]*#' | head -3)
[ -z "$gl" ] && echo "  [PASS] gitolite 설정 잔재 없음" || fail "gitolite 설정 잔재: $gl"

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
    for svc in jenkins plane gitea; do
        if grep -qF -- "- ../../config/web-server/nginx/php/proxy/$svc/:/etc/nginx/proxy.d/$svc/:ro" "$f"; then
            echo "  [PASS] $(basename "$f") $svc"; else fail "$(basename "$f") $svc proxy.d 마운트 없음"; fi
    done
done
if grep -rn '마운트한 conf\.d' "$ROOT"/compose/master_service "$ROOT"/config/web-server/nginx/php/proxy; then fail "conf.d 복사 안내 잔존"; else echo "  [PASS] conf.d 복사 안내 없음"; fi
for svc in jenkins plane gitea; do
    if git -C "$ROOT" check-ignore -q --no-index "config/web-server/nginx/php/proxy/$svc/${svc}_proxy.conf" \
        && ! git -C "$ROOT" check-ignore -q --no-index "config/web-server/nginx/php/proxy/$svc/default.conf"; then
        echo "  [PASS] $svc 복사본 무시·자리표시자 추적"; else fail "$svc proxy 복사본 ignore 규칙"; fi
done

echo "### ensure_env_secrets — master·단독 plane 의 Plane 비밀 키 생성, 비밀 아닌 키 불변, 한 줄 안내 (R2S-02) ###"
# include: 로 참조하는 compose/common/ 까지 필요하므로 compose 트리를 통째로 복사해 상대경로를 보존한다
mkdir -p "$TMPD/mirror" && cp -r "$ROOT/compose" "$TMPD/mirror/"
for d in compose/master_service compose/project_mng_service/nginx_plane; do
    w="$TMPD/mirror/$d"; cp "$ROOT/$d/.env-example" "$w/.env"
    nonsec() { grep -vE '^[A-Z0-9_]*(SECRET|PASSWORD|PWD)[A-Z0-9_]*=|^[A-Z0-9_]*_KEY_BASE=' "$1" | sha256sum; }
    b=$(nonsec "$w/.env"); ( . "$ROOT/script/lib/django_secrets.sh"; ensure_env_secrets "$w/.env" ) >/dev/null 2>&1
    bad=""
    for k in PLANE_SECRET_KEY PLANE_LIVE_SERVER_SECRET_KEY PLANE_DB_PASSWORD PLANE_MQ_PASSWORD PLANE_MINIO_PASSWORD; do
        grep -qE "^$k=[0-9a-f]{32,}\$" "$w/.env" || bad="$bad $k"
    done
    if [ -z "$bad" ] && [ "$(nonsec "$w/.env")" = "$b" ]; then
        echo "  [PASS] $d 헬퍼 실행 → Plane 비밀 키 생성·비밀 아닌 키 불변"; else fail "$d 헬퍼 미생성:${bad:-없음} 또는 비밀 아닌 키 변경"; fi
    if grep -q "ensure_env_secrets $d/.env" "$ROOT/$d/.env-example" && ! grep -q 'openssl rand' "$ROOT/$d/.env-example"; then
        echo "  [PASS] $d .env-example 한 줄 안내"; else fail "$d .env-example 직접 생성(openssl) 안내 잔존 또는 헬퍼 안내 없음"; fi
done

echo "### master_service / project_mng_service compose config (운영 .env 미사용 — .env-example 로 만든 임시 env-file) ###"
n=0
for f in "$ROOT"/compose/master_service/docker-compose-*.yml "$ROOT"/compose/project_mng_service/{nginx_jenkins,nginx_plane,gitea}/docker-compose.yml; do
    d=$(dirname "$f"); n=$((n+1)); envf="$TMPD/$n.env"
    sed -E '/^(DJANGO_SECRET_KEY|REDIS_PASSWORD|FLOWER_PWD|PLANE_SECRET_KEY|PLANE_LIVE_SERVER_SECRET_KEY|PLANE_DB_PASSWORD|PLANE_MQ_PASSWORD|PLANE_MINIO_PASSWORD)=/d' "$d/.env-example" > "$envf" \
        || { fail "$f — $d/.env-example 로 임시 env-file 생성 실패(위 sed 오류)"; continue; }
    printf 'DJANGO_SECRET_KEY=%s\nREDIS_PASSWORD=%s\nFLOWER_PWD=%s\nPLANE_SECRET_KEY=%s\nPLANE_LIVE_SERVER_SECRET_KEY=%s\nPLANE_DB_PASSWORD=%s\nPLANE_MQ_PASSWORD=%s\nPLANE_MINIO_PASSWORD=%s\n' \
        "$(openssl rand -hex 32)" "$(openssl rand -hex 16)" "$(openssl rand -hex 16)" "$(openssl rand -hex 32)" \
        "$(openssl rand -hex 32)" "$(openssl rand -hex 16)" "$(openssl rand -hex 16)" "$(openssl rand -hex 16)" >> "$envf"
    docker compose --env-file "$envf" -f "$f" --profile celery --profile redis config -q \
        && echo "  [PASS] $f" || fail "$f"
done
[ "$n" -eq 8 ] || fail "검사 파일 수 $n (기대 8)"
echo "### tizen-env 연결 설정 — compose 렌더·정적만, 빌드·기동 없음 (TZ-04·05, D-7, D-T1, D-T9) ###"
TZ="$ROOT/compose/dev_env_service/tizen-env"; GT="$ROOT/compose/project_mng_service/gitea"
ports() { docker compose --env-file "$1" -f "$2" config --format json | jq -r '.services[].ports[]? | "\(.host_ip // "0.0.0.0"):\(.published)"'; }
if docker compose --env-file "$TZ/.env-example" -f "$TZ/docker-compose.yml" config -q; then echo "  [PASS] tizen-env config"; else fail "tizen-env config"; fi
tz=$(ports "$TZ/.env-example" "$TZ/docker-compose.yml"); gl=$(ports "$GT/.env-example" "$GT/docker-compose.yml")
[ "$tz" = "127.0.0.1:2221" ] && echo "  [PASS] tizen-env SSH $tz" || fail "tizen-env SSH publish=$tz (기대 127.0.0.1:2221)"
dup=$(printf '%s\n%s\n' "$tz" "$gl" | sed 's/.*://' | sort | uniq -d)
[ -n "$gl" ] && [ -z "$dup" ] && echo "  [PASS] 단독 tizen-env ∩ gitea = ∅ (2221 vs 2222)" || fail "단독 포트 중복 또는 gitea 렌더 실패: ${dup:-포트 0}"
# master php 는 config 루프 순번과 무관하게 .env-example 로 직접 렌더 — php 가 :? 로 요구하는 빈 비밀 2개는 셸 환경값이 env-file 보다 우선, 렌더 실패(포트 0)도 FAIL
mp=$(REDIS_PASSWORD=x PLANE_SECRET_KEY=x PLANE_LIVE_SERVER_SECRET_KEY=x PLANE_DB_PASSWORD=x PLANE_MQ_PASSWORD=x PLANE_MINIO_PASSWORD=x ports "$ROOT/compose/master_service/.env-example" "$ROOT/compose/master_service/docker-compose-php.yml")
dup=$(printf '%s\n' "$mp" | sed 's/.*://' | sort | uniq -d)
[ -n "$mp" ] && [ -z "$dup" ] && echo "  [PASS] master php 포트 중복 없음" || fail "master php 포트 중복 또는 렌더 실패: ${dup:-포트 0}"
if TIZEN_SSH_KEY= docker compose --env-file "$TZ/.env-example" -f "$TZ/docker-compose.yml" config -q 2>/dev/null; then
    fail "TIZEN_SSH_KEY 빈 값인데 config 성공 (fail-fast 없음)"; else echo "  [PASS] TIZEN_SSH_KEY 필수"; fi
# Match 앞 유효 줄(대소문자 무시)이 전부 기대값 — sshd 가 쓰는 첫 값·마지막 값 모두 보장, 줄이 없어도 FAIL
for k in "PermitRootLogin prohibit-password" "PasswordAuthentication no" "X11Forwarding no" "AllowTcpForwarding no"; do
    v=$(awk -v k="${k%% *}" 'tolower($1)=="match"{exit} tolower($1)==tolower(k){print $2}' "$ROOT/docker/tizen-env/system/sshd_config" | sort -u | paste -sd,)
    [ "$v" = "${k#* }" ] && echo "  [PASS] tizen-env $k" || fail "tizen-env sshd_config — $k 아님(유효 값: ${v:-없음})"
done
# README 의 authorized_keys root 소유 필수 근거 — 주석·미설정은 기본값 yes 라 PASS, 명시적 no 만 FAIL
awk 'tolower($1)=="match"{exit} tolower($1)=="strictmodes" && tolower($2)=="no"{f=1} END{exit !f}' "$ROOT/docker/tizen-env/system/sshd_config" && fail "tizen-env sshd_config — StrictModes no (README authorized_keys root 소유 근거 무효)" || echo "  [PASS] tizen-env StrictModes no 아님"
if grep -q 'id_rsa' "$ROOT/docker/tizen-env/Dockerfile"; then fail "Dockerfile 이 id_rsa 를 이미지에 넣음"; else echo "  [PASS] Dockerfile id_rsa 없음"; fi
echo "### jenkins_home 소유권 — jenkins-init(root 1회 chown 1000) 뒤 jenkins 기동, 호스트 uid 가 1000 이 아니어도 재시작 루프 없음 (LIVE-R1-JENKINS) ###"
for f in "$ROOT"/compose/master_service/docker-compose-*.yml "$ROOT"/compose/project_mng_service/nginx_jenkins/docker-compose.yml; do
    j=$(awk '/^  jenkins-init:$/{f=1;next} f&&/^  [a-z]/{f=0} f' "$f")
    k=$(awk '/^  jenkins:$/{f=1;next} f&&/^  [a-z]/{f=0} f' "$f")
    if grep -q 'user: "0:0"' <<<"$j" && grep -qF 'entrypoint: ["chown", "1000:1000", "/var/jenkins_home"]' <<<"$j" && grep -q 'restart: "no"' <<<"$j" \
        && grep -A1 'jenkins-init:' <<<"$k" | grep -q 'condition: service_completed_successfully'; then
        echo "  [PASS] ${f#$ROOT/} jenkins-init → jenkins"; else fail "${f#$ROOT/} jenkins-init 없음 또는 jenkins 가 완료 대기 안 함"; fi
done

echo "### Harbor 설정 생성기 — 일반 경로·특수문자 입력, 인증서 경로에 입력 도메인 (LIVE-R1-HARBOR) ###"
HB="$ROOT/compose/project_mng_service/harbor-v2.0.0"
if grep -q 'cococok' "$HB/sample-harbor.yml"; then fail "sample-harbor.yml 에 고정 도메인 잔존"; else echo "  [PASS] sample-harbor.yml 고정 도메인 없음"; fi
for g in update_harbor_config.sh autoinstall.sh; do
    w="$TMPD/hb-$g"; mkdir -p "$w"; cp "$HB/update_harbor_config.sh" "$HB/sample-harbor.yml" "$w/"
    # autoinstall.sh 는 설치 전까지(harbor.yml 생성)만 같은 입력 처리 — 생성부만 잘라 검사
    sed '/^echo "created a harbor.yml successfully!!!"/,$d' "$HB/$g" > "$w/gen.sh"
    ( cd "$w" && printf 'ex.test\n8080\ny\n8443\n/opt/my ssl\nA&b/c\\d\ndb pw\n/srv/h data\n\\/var\\/log\\/hb\n' | bash gen.sh >/dev/null 2>&1 )
    y="$w/harbor.yml"
    if [ -f "$y" ] && grep -qx 'hostname: ex.test' "$y" && grep -qx '  port: 8080' "$y" && grep -qx '  port: 8443' "$y" \
        && grep -qx '  certificate: /opt/my ssl/letsencrypt/live/ex.test/fullchain.pem' "$y" \
        && grep -qx '  private_key: /opt/my ssl/letsencrypt/live/ex.test/privkey.pem' "$y" \
        && grep -qxF 'harbor_admin_password: A&b/c\d' "$y" && grep -qx '  password: db pw' "$y" \
        && grep -qx 'data_volume: /srv/h data ' "$y" && grep -qx '    location: /var/log/hb' "$y"; then
        echo "  [PASS] $g 생성 harbor.yml (경로·특수문자·레거시 \\/ 입력·도메인 인증서 경로)"
    else fail "$g 생성 harbor.yml 불일치: $(grep -E '^hostname|certificate:|harbor_admin_password: [^H]|^  password: [^r]|data_volume: /|location: /' "$y" 2>/dev/null | tr '\n' ';')"; fi
done
if grep -qF 'cp -rf ssl/. "$sslpath/"' "$HB/autoinstall.sh"; then echo "  [PASS] autoinstall ssl 내용을 <ssl path>/ 아래로 복사"; else fail "autoinstall ssl 복사 경로"; fi

echo "### tizenenv 는 amd64 전용 — compose 에 platform: linux/amd64 고정 (LIVE-R1-TIZENARCH) ###"
for f in "$ROOT/compose/master_service/docker-compose-php.yml" "$ROOT/compose/dev_env_service/tizen-env/docker-compose.yml"; do
    if awk '/^  tizenenv:$/{f=1;next} f&&/^  [a-z]/{f=0} f' "$f" | grep -qx '    platform: linux/amd64'; then
        echo "  [PASS] ${f#$ROOT/} tizenenv platform linux/amd64"; else fail "${f#$ROOT/} tizenenv platform 미고정(arm64 호스트에서 gbs 의존성 설치 불가)"; fi
done

echo "### tizen-env ssh 설정 — config 파싱 가능·known_hosts 가 비표준 포트 형식([host]:port) (LIVE-R2-TIZENSSH) ###"
TZS="$ROOT/docker/tizen-env/.ssh"
if o=$(ssh -G -F "$TZS/config" tizen 2>&1) && grep -qx 'hostname review.tizen.org' <<<"$o" && grep -qx 'port 29418' <<<"$o"; then
    echo "  [PASS] ssh -G 로 config 파싱 (tizen → review.tizen.org:29418)"; else fail "tizen-env .ssh/config 파싱 실패: $(head -c 200 <<<"$o")"; fi
# 컨테이너(Ubuntu 18.04, OpenSSH 7.6)는 줄 끝 주석을 "garbage at end of line" 으로 거부 — 호스트 ssh 가 최신이면 위 파싱은 통과하므로 따로 검사
if grep -nE '^[[:space:]]*[^#[:space:]][^#]*[[:space:]]#' "$TZS/config"; then fail "tizen-env .ssh/config 줄 끝 주석(구버전 ssh 파싱 실패)"; else echo "  [PASS] config 줄 끝 주석 없음"; fi
if ssh-keygen -F '[review.tizen.org]:29418' -f "$TZS/known_hosts" >/dev/null; then
    echo "  [PASS] known_hosts 에 [review.tizen.org]:29418 항목"; else fail "tizen-env known_hosts 가 [review.tizen.org]:29418 형식이 아님(호스트 키 검증 항상 실패)"; fi

echo "=== RESULT: FAILS=$FAILS ==="
[ "$FAILS" -eq 0 ] || exit 1
