#!/usr/bin/env bash
# Section 6: static regression
set +e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

FAILS=0
# 검사 결과를 출력만 하지 않고 명시적으로 판정한다 (과거: matches=N 만 출력 → 자동 게이트로 무의미).
assert_zero() { local label="$1" n="$2"; if [ "$n" -eq 0 ] 2>/dev/null; then echo "  PASS $label (matches=$n)"; else echo "  FAIL $label (matches=$n, expected 0)"; FAILS=$((FAILS+1)); fi; }
assert_eq()   { local label="$1" n="$2" exp="$3"; if [ "$n" -eq "$exp" ] 2>/dev/null; then echo "  PASS $label ($n)"; else echo "  FAIL $label ($n, expected $exp)"; FAILS=$((FAILS+1)); fi; }

echo "===== 6.1 host injection regex bug ====="
n=$(grep -rE 'domain\\\.\\\(com' config/web-server/ 2>/dev/null | wc -l)
assert_zero 6.1 "$n"
echo

echo "===== 6.2 CSP frame-ancestors 'self' uniform ====="
# expected: no rows that are NOT 'self'
out=$(grep -rE "frame-ancestors '?self'?[^;]*;" config/web-server/ 2>/dev/null | grep -v "'self';" | grep -v "'self' ")
if [ -z "$out" ]; then
    echo "  PASS 6.2 — all frame-ancestors are 'self;'"
else
    echo "  FAIL 6.2 — non-'self' rows:"; echo "$out"; FAILS=$((FAILS+1))
fi
echo

echo "===== 6.3 log filename pattern (legacy _(http|https)_(access|error).log) ====="
n=$(grep -rE "_(http|https)_(access|error)\.log" config/web-server/ 2>/dev/null | wc -l)
assert_zero 6.3 "$n"
echo

echo "===== 6.4 LF line endings (no CRLF) ====="
n=$(git ls-files -z 2>/dev/null | xargs -0 file 2>/dev/null | grep -c CRLF)   # 추적 파일만 — 스택 기동이 만든 gitignore 런타임 파일(jenkins 등) 제외 (CL-WP5-01-R4)
echo "  (first 10 if any):"
git ls-files -z 2>/dev/null | xargs -0 file 2>/dev/null | grep CRLF | head -10
assert_zero 6.4 "$n"
echo

echo "===== 6.5 unmatched-Host catch-all = default.conf (no host-injection if in samples) ====="
# 정책: sample / generated conf 에는 `if ($host !~)` 가 있어선 안 된다.
# 알 수 없는 Host/SNI 차단은 default.conf 의 default_server (return 444 / ssl_reject_handshake) 가 단일 책임으로 담당.
n=$(grep -rnE 'if[[:space:]]*\([[:space:]]*\$host[[:space:]]*!~' config/web-server/ 2>/dev/null | wc -l)
grep -nE 'default_server' config/web-server/nginx/gunicorn/conf.d/default.conf | head -3
assert_zero 6.5 "$n"
echo

echo "===== 6.6 uwsgi log-maxsize / log-reopen ====="
grep -nE '^(log-maxsize|log-reopen)' config/app-server/uwsgi/uwsgi.ini
n=$(grep -cE '^(log-maxsize|log-reopen)' config/app-server/uwsgi/uwsgi.ini)
assert_eq 6.6 "$n" 2
echo

echo "===== 6.7 django_sample uv-only (no [tool.poetry]) ====="
n=$(grep -cE '\[tool\.poetry\]' www/django_sample/pyproject.toml)
assert_zero 6.7 "$n"
echo

echo "===== 6.8 django_sample .python-version (info) ====="
cat www/django_sample/.python-version 2>/dev/null || echo "(no .python-version)"
echo

echo "===== 6.9 django_sample legacy-cgi shim ====="
if grep -q legacy-cgi www/django_sample/pyproject.toml; then
    echo "  PASS 6.9"
else
    echo "  FAIL 6.9 (legacy-cgi shim missing)"; FAILS=$((FAILS+1))
fi
echo

echo "===== 6.10 D-1 B: addr/flood zone 은 nginx.conf 가 \$bot_iplimit 키로 1회 정의 (settings include·bot2/bot4 직접 정의 없음) ====="
for f in config/web-server/nginx/{gunicorn,uvicorn,uwsgi,php}/nginx_conf/nginx.conf; do
    assert_eq   "6.10 zone=addr 1회 ($f)" "$(grep -c 'zone=addr' "$f")" 1
    assert_eq   "6.10 \$bot_iplimit addr/flood ($f)" "$(grep -cE '^[[:space:]]*limit_(conn|req)_zone[[:space:]]+\$bot_iplimit[[:space:]]+zone=(addr|flood):' "$f")" 2
    assert_zero "6.10 settings include ($f)" "$(grep -cE '^[[:space:]]*include[[:space:]]+/etc/nginx/botblocker-nginx-settings\.conf' "$f")"
    assert_zero "6.10 bot2/bot4 zone 직접 정의 ($f)" "$(grep -cE '^[[:space:]]*limit_(conn|req)_zone.*zone=bot[24]_' "$f")"
    assert_eq   "6.10 globalblacklist include ($f)" "$(grep -cE '^[[:space:]]*include[[:space:]]+/etc/nginx/globalblacklist\.conf;' "$f")" 1
done
echo

echo "===== 6.11 출고 conf.d·템플릿 server 블록은 bots.d/blockbots.conf + ddos.conf 만 include ====="
for f in config/web-server/nginx/{gunicorn,uvicorn,uwsgi,php}/conf.d/*_ng_http.conf config/web-server/nginx/*/sample_nginx_http*.conf; do
    b=$(grep -cE '^[[:space:]]*include[[:space:]]+/etc/nginx/bots\.d/blockbots\.conf;' "$f")
    d=$(grep -cE '^[[:space:]]*include[[:space:]]+/etc/nginx/bots\.d/ddos\.conf;' "$f")
    a=$(grep -cE '^[[:space:]]*include[[:space:]]+/etc/nginx/bots\.d/' "$f")
    if [ "$b" = 1 ] && [ "$d" = 1 ] && [ "$a" = 2 ]; then echo "  PASS 6.11 ($f)"; else echo "  FAIL 6.11 ($f) blockbots=$b ddos=$d bots.d_total=$a"; FAILS=$((FAILS+1)); fi
done
echo

echo "===== 6.12 호스트 소스 트리 소유권 불변 — /www chown 없음·PROJECT_DIR 가드·SECRET_KEY env·SQLite 데이터 볼륨 (RV1-S-01, RV1-SEC-03) ====="
for f in compose/web_service/nginx_{gunicorn,uvicorn,uwsgi,daphne}/docker-compose.yml; do
    assert_zero "6.12 /www chown ($f)" "$(grep -cE 'chown[^"]*/www/' "$f")"
    assert_zero "6.12 가드 없는 PROJECT_DIR 치환 ($f)" "$(grep -cF '${PROJECT_DIR}' "$f")"
    assert_eq   "6.12 DJANGO_SECRET_KEY :? ×3 ($f)" "$(grep -cF 'DJANGO_SECRET_KEY: "${DJANGO_SECRET_KEY:?' "$f")" 3
    assert_eq   "6.12 SQLITE_PATH ×3 ($f)" "$(grep -cE '^[[:space:]]+SQLITE_PATH: ' "$f")" 3
    assert_eq   "6.12 app-data:/data ×3 ($f)" "$(grep -cE '^[[:space:]]+- app-data:/data$' "$f")" 3
done
assert_eq "6.12 settings.py DJANGO_SECRET_KEY·SQLITE_PATH env" "$(grep -cE 'environ\.get\("(DJANGO_SECRET_KEY|SQLITE_PATH)"' www/django_sample/config/settings.py)" 2
echo

echo "===== 6.13 X-Forwarded-Proto 는 nginx 가 \$scheme 로 덮어쓴다 (RV1-SEC-01) ====="
for f in config/web-server/nginx/uwsgi/sample_nginx_http.conf config/web-server/nginx/uwsgi/sample_nginx_https.conf config/web-server/nginx/uwsgi/conf.d/*_ng_http.conf; do
    p=$(grep -cE '^[[:space:]]*uwsgi_pass[[:space:]]' "$f"); x=$(grep -cE '^[[:space:]]*uwsgi_param[[:space:]]+HTTP_X_FORWARDED_PROTO[[:space:]]+\$scheme;' "$f")
    if [ "$p" -ge 1 ] && [ "$p" = "$x" ]; then echo "  PASS 6.13 ($f)"; else echo "  FAIL 6.13 ($f) uwsgi_pass=$p forwarded_proto=$x"; FAILS=$((FAILS+1)); fi
done
for f in config/web-server/nginx/{gunicorn,uvicorn,php}/proxy_params/proxy_params; do
    assert_eq "6.13 proxy X-Forwarded-Proto \$scheme ($f)" "$(grep -cE '^proxy_set_header[[:space:]]+X-Forwarded-Proto[[:space:]]+\$scheme;' "$f")" 1
done
echo

echo "===== 6.14 차단 location 우선 — 최상위 첫 regex·/media·/static 안 첫 location 은 dotfile 차단, php 업로드 차단은 정적 자산보다 앞 (RV1-SEC-05) ====="
loc_order() {
    awk '
    { l = $0; sub(/#.*/, "", l) }
    l ~ /^[[:space:]]*server[[:space:]]*\{/ { top = 0 }
    l ~ /^[[:space:]]*location[[:space:]]/ {
        if (depth == 1) {
            nested = (l ~ /location[[:space:]]+\/(media|static)[[:space:]]*\{/)
            if (l ~ /location[[:space:]]+~/ && !top) { top = 1; if (l !~ /location[[:space:]]+~[[:space:]]+\/\\\.[[:space:]]*\{/) { print "    최상위 첫 regex: " $0; bad++ } }
            if (l ~ /uploads\|default/) up = NR
            if (l ~ /location[[:space:]]+~\*[[:space:]]+\\\.\(js\|css/) st = NR
        } else if (depth == 2 && nested) {
            nested = 0
            if (l !~ /location[[:space:]]+~[[:space:]]+\/\\\.[[:space:]]*\{/) { print "    /media·/static 첫 중첩 location: " $0; bad++ }
        }
    }
    { o = l; depth += gsub(/\{/, "", o); o = l; depth -= gsub(/\}/, "", o) }
    END { if (up && st && up > st) { print "    업로드 PHP 차단이 정적 자산 regex 뒤"; bad++ }; exit (bad > 0) }' "$1"
}
for f in config/web-server/nginx/*/sample_nginx_http*.conf config/web-server/nginx/{gunicorn,uvicorn,uwsgi,php}/conf.d/*_ng_http.conf; do
    if out=$(loc_order "$f"); then echo "  PASS 6.14 ($f)"; else echo "  FAIL 6.14 ($f)"; echo "$out"; FAILS=$((FAILS+1)); fi
done
echo

echo "===== 6.15 php-fpm pool 예시 security.limit_extensions·기본 pool 포트 충돌 안내 (RV1-SEC-06, RV1-S-02) ====="
assert_eq   "6.15 limit_extensions (php example)" "$(grep -cE '^security\.limit_extensions[[:space:]]*=[[:space:]]*\.php' config/app-server/php/pool.d/sample_php.conf.example)" 1
assert_zero "6.15 www.conf '복사해 추가' 충돌 안내 (php)" "$(grep -c '복사해 \*\.conf 로 추가한다' config/app-server/php/pool.d/www.conf)"
n=$(grep -c 'www.conf' config/app-server/php/php_conf.sh)
if [ "$n" -ge 1 ]; then echo "  PASS 6.15 php_conf.sh 포트 충돌 안내 (php) ($n)"; else echo "  FAIL 6.15 php_conf.sh 포트 충돌 안내 없음 (php)"; FAILS=$((FAILS+1)); fi
echo

echo "===== 6.16 알림·아티팩트 비밀값 마스킹 — 누락 형식 마스킹·정상 줄 비마스킹 (RV1-SEC-04, RV2-S-04, RV2-SEC-01/02) ====="
if [ -f script/lib/mask_secrets.sh ]; then
    # shellcheck source=../lib/mask_secrets.sh
    . script/lib/mask_secrets.sh
    leak=$(printf '%s\n' 'echo REDIS_PASSWORD=dummysecret' 'TELEGRAM_BOT_TOKEN: dummysecret' 'redis://:dummysecret@redis:6379/3' \
        '{"SECRET_KEY": "dummysecret"}' 'FLOWER_BASIC_AUTH=tester:dummysecret' 'redis-server --requirepass dummysecret' \
        'Authorization: Bearer dummysecret' "DJANGO_SECRET_KEY='dummy secret'" 'FLOWER_PWD="dummy secret"' \
        'redis-server --requirepass "dummy secret"' 'redis-cli --no-auth-warning -a dummysecret ping' 'requirepass dummysecret' \
        '"command": ["redis-server", "--requirepass", "dummysecret"]' 'REDIS_PASSWORD="dum\"my,secret"' '{"SECRET_KEY": "dummy,secret", "x": 1}' \
        '"Authorization": "Bearer dummysecret"' "redis-server --requirepass 'dummy secret'" "redis-cli -a 'dummy secret' ping" \
        "requirepass 'dummy dummytail" 'redis-server --requirepass "dummy dummytail' "redis-cli -a 'dummy dummytail" \
        "DJANGO_SECRET_KEY='dummy dummytail" 'FLOWER_PWD="dummy dummytail' | mask_secrets | grep -c dummy)
    assert_zero "6.16 누락 형식 포함 마스킹 샘플 23종 누출 (작은따옴표 RV3-S-02, 잘린 로그의 닫히지 않은 따옴표 R4-04)" "$leak"
    keep='RUNTIME_PASS=5
ALL PASS: dhparam
invalid token format
  [PASS] B.1 app reached (healthy)
    ssl_certificate_key /etc/nginx/ssl/default/privkey.pem;
Final: STATIC_FAIL=0 RUNTIME_PASS=12 RUNTIME_FAIL=0'
    if [ "$(printf '%s\n' "$keep" | mask_secrets)" = "$keep" ]; then echo "  PASS 6.16 정상 줄 비마스킹 6종"; else echo "  FAIL 6.16 정상 줄 과마스킹"; printf '%s\n' "$keep" | mask_secrets | sed 's/^/    /'; FAILS=$((FAILS+1)); fi
else
    echo "  FAIL 6.16 script/lib/mask_secrets.sh 없음"; FAILS=$((FAILS+1))
fi
assert_eq   "6.16 run-ci 알림 본문·로그 파일 마스킹 호출" "$(grep -cE '^[[:space:]]*mask_secrets_files[[:space:]]|\|[[:space:]]*mask_secrets\)' script/ci/run-ci.sh)" 2
assert_zero "6.16 run-ci 마스킹 실패 삼킴(|| true)" "$(grep -cE 'mask_secrets_files.*\|\| true' script/ci/run-ci.sh)"
m=$(grep -n 'mask_secrets_files log/ci log/test_run' .github/workflows/test.yml | head -1 | cut -d: -f1); u=$(grep -n 'actions/upload-artifact' .github/workflows/test.yml | head -1 | cut -d: -f1)
if [ -n "$m" ] && [ -n "$u" ] && [ "$m" -lt "$u" ]; then echo "  PASS 6.16 test.yml 업로드 직전 마스킹 단계"; else echo "  FAIL 6.16 test.yml 업로드 전 마스킹 단계 없음"; FAILS=$((FAILS+1)); fi
assert_eq   "6.16 test.yml 마스킹 단계 id: mask" "$(grep -cE '^[[:space:]]+id: mask$' .github/workflows/test.yml)" 1
assert_eq   "6.16 test.yml 업로드는 마스킹 성공 시에만 (RV3-SEC-04)" "$(grep -cF "if: always() && steps.mask.outcome == 'success'" .github/workflows/test.yml)" 1
echo

echo "===== 6.17 하네스는 운영 .env 를 수정·생성하지 않고 임시 env-file·전용 compose 프로젝트로 격리 (RV1-SEC-02) ====="
for f in script/test_run/verify_integration_*.sh script/test_run/verify_compose_yml.sh script/test_run/verify_healthcheck.sh script/test/verify-ngxblocker.sh; do
    w=$(grep -cE 'sed -i.*\.env|cp \.env-example \.env|>[[:space:]]*\.env([[:space:]]|$)' "$f"); e=$(grep -c -- '--env-file' "$f")
    if [ "$w" = 0 ] && [ "$e" -ge 1 ]; then echo "  PASS 6.17 ($f)"; else echo "  FAIL 6.17 ($f) env_write=$w env_file=$e"; FAILS=$((FAILS+1)); fi
done
assert_eq "6.17 healthcheck 프로젝트명에서 . 치환 (compose 이름 규칙)" "$(grep -cF 'PROJ="devspoon-hc-${STACK//./-}"' script/test_run/verify_healthcheck.sh)" 1
for f in script/test_run/verify_integration_*.sh script/test_run/verify_healthcheck.sh script/test/verify-ngxblocker.sh; do
    assert_eq "6.17 전용 compose 프로젝트명 ($f)" "$(grep -cE 'docker compose -p "\$PROJ"' "$f")" 1
done
echo

echo "===== 6.18 컨테이너 안정성 판정 — 순간 running 이 아니라 안정화 창 전후 RestartCount 불변 (TC-F9-1) ====="
if [ -f script/lib/stability.sh ]; then
    # shellcheck source=../lib/stability.sh
    . script/lib/stability.sh
    judge_case() { local got; if stable_judge "$2" "$3"; then got=pass; else got=fail; fi
        if [ "$got" = "$1" ]; then echo "  PASS 6.18 [$2]→[$3] = $1"; else echo "  FAIL 6.18 [$2]→[$3] = $got (expected $1)"; FAILS=$((FAILS+1)); fi; }
    judge_case pass "running 0 healthy" "running 0 healthy"
    judge_case pass "running 0 none"    "running 0 none"
    judge_case fail "running 0 none"    "running 4 none"
    judge_case fail "running 0 none"    "restarting 5 none"
    judge_case fail "running 0 starting" "running 0 unhealthy"
    judge_case fail "running 1 none"    "running 1 none"
    judge_case fail ""                  ""
else
    echo "  FAIL 6.18 script/lib/stability.sh 없음"; FAILS=$((FAILS+1))
fi
for f in script/test_run/verify_integration_*.sh; do
    assert_eq   "6.18 app·webserver containers_stable 사용 ($f)" "$(grep -cF 'containers_stable "$(cid $APP)" "$(cid webserver)"' "$f")" 1
    assert_zero "6.18 순간 RestartCount 판정 ($f)" "$(grep -c '{{.RestartCount}}' "$f")"
done
assert_eq   "6.18 verify_healthcheck B.2 containers_stable" "$(grep -c 'containers_stable ' script/test_run/verify_healthcheck.sh)" 1
assert_zero "6.18 verify_healthcheck 순간 running 0 판정" "$(grep -c '"running 0"' script/test_run/verify_healthcheck.sh)"
assert_eq   "6.18 verify_healthcheck 런타임 teardown trap (RV1-S-06)" "$(grep -cE "^trap 'dc .*down -v" script/test_run/verify_healthcheck.sh)" 1
echo

echo "===== 6.19 앱 이미지 사전설치 = django_sample uv.lock 해석 결과 (기동마다 uv sync 재설치 방지, CL-WP2-09-R4) ====="
lockv() { awk -v n="$1" '$0 == "name = \"" n "\"" { getline; gsub(/"/, "", $3); print $3; exit }' "${2:-www/django_sample/uv.lock}"; }
for df in docker/gunicorn/Dockerfile docker/uwsgi/Dockerfile; do
    assert_eq   "6.19 lock 입력 COPY --from=lock ($df)" "$(grep -cx 'COPY --from=lock pyproject.toml uv.lock /tmp/lock/' "$df")" 1
    # 잔여 위험 2: lock 컨텍스트 누락 시 이미지 pull 오류(lock:latest) 대신 '/pyproject.toml: not found' — 빈 기본 스테이지, --build-context 가 덮어씀
    assert_eq   "6.19 lock 빈 기본 스테이지 FROM scratch AS lock ($df)" "$(grep -cx 'FROM scratch AS lock' "$df")" 1
    assert_eq   "6.19 uv export --frozen ($df)" "$(grep -c 'uv export --frozen' "$df")" 1
    assert_eq   "6.19 pip install -r lock 해석 ($df)" "$(grep -c 'pip install --no-cache-dir -r /tmp/lock/requirements.txt' "$df")" 1
    assert_eq   "6.19 그 밖의 사전설치는 -c lock 제약 ($df)" "$(grep -c 'pip install --no-cache-dir -c /tmp/lock/requirements.txt' "$df")" 1
    assert_zero "6.19 lock 과 이중 관리되는 == 고정 ($df)" "$(grep -cE '(gunicorn|uvicorn|uwsgi|django)(\[standard\])?==' "$df")"
done
for s in gunicorn uvicorn uwsgi daphne; do
    f=compose/web_service/nginx_$s/docker-compose.yml
    df=$(grep -m1 -oE 'docker/(gunicorn|uwsgi)/' "$f")Dockerfile
    assert_eq "6.19 compose additional_contexts lock=django_sample ($s)" "$(grep -c 'lock: \.\./\.\./\.\./www/django_sample$' "$f")" 1
    for x in $(grep -m1 -oE 'uv sync --inexact( --extra [a-z]+)+' "$f" | grep -oE -- '--extra [a-z]+' | awk '{print $2}'); do
        assert_eq "6.19 $df export --extra $x (nginx_$s app)" "$(grep -A2 'uv export --frozen' "$df" | grep -cE -- "--extra $x( |$)")" 1
    done
done
assert_eq "6.19 s2_build --build-context lock" "$(grep -c -- '--build-context lock=' script/test_run/s2_build.sh)" 1
assert_eq "6.19 s2_build 빌드 이미지에서 uv sync --dry-run 대조" "$(grep -c 'sync --frozen --inexact --dry-run' script/test_run/s2_build.sh)" 1
assert_zero "6.19 django_sample 미사용 pytz" "$(grep -c 'pytz' www/django_sample/pyproject.toml)"
echo

echo "===== 6.20 sample_uwsgi.ini = uwsgi.ini (placeholder p_num·th_num·port_num 3줄 외 동일), 생성기에 고정 프로젝트 경로 없음 (RV1-S-07) ====="
if [ "$(sed -e 's/p_num/4/g' -e 's/th_num/2/g' -e 's/port_num/8000/g' config/app-server/uwsgi/sample_uwsgi.ini)" = "$(cat config/app-server/uwsgi/uwsgi.ini)" ]; then
    echo "  PASS 6.20 sample_uwsgi.ini 동기화"
else
    echo "  FAIL 6.20 sample_uwsgi.ini ≠ uwsgi.ini"; FAILS=$((FAILS+1))
fi
assert_zero "6.20 개인 경로 주석(linku) (RV2-SEC-04)" "$(cat config/app-server/uwsgi/uwsgi.ini config/app-server/uwsgi/sample_uwsgi.ini | grep -ci linku)"
assert_zero "6.20 uwsgi_conf.sh project_path/project_name 치환" "$(grep -cE 'project_(path|name)' config/app-server/uwsgi/uwsgi_conf.sh)"
echo

echo "===== 6.21 DJANGO_ALLOWED_HOSTS 기본값에 nginx server_name 의 www.localhost 포함 (RV1-S-05) ====="
assert_eq "6.21 settings.py" "$(grep -c '"localhost,www.localhost,127.0.0.1"' www/django_sample/config/settings.py)" 1
for s in gunicorn uvicorn uwsgi daphne; do
    assert_eq "6.21 compose ($s)"      "$(grep -c 'DJANGO_ALLOWED_HOSTS:-localhost,www.localhost,127.0.0.1}' compose/web_service/nginx_$s/docker-compose.yml)" 3
    assert_eq "6.21 .env-example ($s)" "$(grep -c '^DJANGO_ALLOWED_HOSTS=localhost,www.localhost,127.0.0.1$' compose/web_service/nginx_$s/.env-example)" 1
done
echo

echo "===== 6.17b (형제) 검증기는 격리 래퍼 dc() 밖에서 docker compose 를 직접 호출하지 않는다 (SRV1-S-01, RV1-SEC-02) ====="
for f in script/test_run/verify_integration_*.sh script/test_run/verify_healthcheck.sh script/test/verify-ngxblocker.sh; do
    assert_zero "6.17b 래퍼 밖 docker compose 직접 호출 ($f)" "$(grep -vE '^[[:space:]]*#|^[[:space:]]*dc\(\)' "$f" | grep -c 'docker compose')"
done
echo

echo "===== 6.17c (형제) pipefail 검증기에서 exec 출력을 grep -q 로 직접 파이프하지 않음 — SIGPIPE 로 exec 255 거짓 FAIL (CL-WP5-05-R3) ====="
assert_zero "6.17c exec … | grep -q (verify_integration_*)" "$(grep -hE 'exec[^|]*\|[[:space:]]*grep -q' script/test_run/verify_integration_*.sh | grep -vc '^[[:space:]]*#')"
echo

echo "===== 6.22 DB 초기화(Django migrate·비Django prestart.sh)는 app 서비스에서만 기동 전 1회, celery·beat 는 app healthy 뒤 기동 (CL-WP1-08-R2b, CL-WP1-08-R4) ====="
for s in gunicorn uvicorn uwsgi daphne; do
    f=compose/web_service/nginx_$s/docker-compose.yml
    assert_eq "6.22 migrate 1회(app 만) ($s)" "$(grep -c 'manage.py migrate --noinput' "$f")" 1
    assert_eq "6.22 uv sync → migrate → prestart.sh → /data chown → 서버 순서 ($s)" "$(grep -cF '{ [ ! -f manage.py ] || python manage.py migrate --noinput; } && { [ ! -f prestart.sh ] || bash prestart.sh; } && chown -R www-data:www-data /data && ' "$f")" 1
    assert_eq "6.22 ${s}-app service_healthy 의존 3곳(webserver·celery·beat) ($s)" "$(grep -A1 -E "^      ${s}-app:\$" "$f" | grep -c 'condition: service_healthy')" 3
    assert_zero "6.22 옛 주석 '앱이 create_all' — 실제는 prestart.sh 1회 (RV7-02, $s)" "$(grep -c '앱이 create_all' "$f")"
done
echo

echo "===== 6.23 s5_https 는 출고 http 샘플과 겹치지 않는 도메인 + reload 후 준비 대기 (CL-WP4-08-R2) ====="
assert_zero "6.23 s5 -d localhost (출고 http 샘플 server_name 충돌)" "$(grep -c -- '-d localhost' script/test_run/s5_https.sh)"
n=$(grep -c 'S5_WAIT' script/test_run/s5_https.sh)
if [ "$n" -ge 2 ]; then echo "  PASS 6.23 s5 준비 대기 ($n)"; else echo "  FAIL 6.23 s5 준비 대기 없음"; FAILS=$((FAILS+1)); fi
# CL-WP4-08-R4: 5.1 은 OpenSSL 1.1·3 공통 -brief 출력(Protocol version·Ciphersuite)으로 판정 — OpenSSL 3 TLS1.3 은 `Protocol  :` 줄 없음
assert_zero "6.23 s5 5.1 OpenSSL 3 미출력 'Protocol *:' 요구" "$(grep -c 'Protocol \*:' script/test_run/s5_https.sh)"
assert_eq   "6.23 s5 5.1 s_client -brief 협상 프로토콜 판정" "$(grep -c "Protocol version: \*TLSv1" script/test_run/s5_https.sh)" 1
echo

echo "===== 6.24 .env 비밀값 한 줄 생성 헬퍼 — 빈 값·CHANGE_ME 는 채우고 기존 값·비밀 아닌 키는 불변 (RV2-S-01, 3회차 13) ====="
if grep -q 'ensure_env_secrets()' script/lib/django_secrets.sh; then
    tmp=$(mktemp -d)
    printf 'FLOWER_ID=CHANGE_ME_FLOWER_USER\nDJANGO_SECRET_KEY=\nREDIS_PASSWORD=CHANGE_ME_REDIS_PASSWORD\nFLOWER_PWD=\n' > "$tmp/new.env"
    printf 'DJANGO_SECRET_KEY=keepme\nREDIS_PASSWORD=keep-redis\nFLOWER_PWD=keep-flower\n' > "$tmp/keep.env"; ks=$(sha256sum < "$tmp/keep.env")
    ( . script/lib/django_secrets.sh
      ensure_env_secrets "$tmp/new.env" >/dev/null; ensure_env_secrets "$tmp/keep.env" >/dev/null
      ensure_env_secrets "$tmp/none.env" >/dev/null 2>&1; echo "rc_none=$?" > "$tmp/rc" )
    assert_eq   "6.24 DJANGO_SECRET_KEY 빈 값 → 100 hex" "$(grep -cE '^DJANGO_SECRET_KEY=[0-9a-f]{100}$' "$tmp/new.env")" 1
    assert_eq   "6.24 REDIS_PASSWORD CHANGE_ME → 64 hex" "$(grep -cE '^REDIS_PASSWORD=[0-9a-f]{64}$' "$tmp/new.env")" 1
    assert_eq   "6.24 FLOWER_PWD 빈 값 → 64 hex" "$(grep -cE '^FLOWER_PWD=[0-9a-f]{64}$' "$tmp/new.env")" 1
    assert_eq   "6.24 비밀 아닌 FLOWER_ID 불변" "$(grep -c '^FLOWER_ID=CHANGE_ME_FLOWER_USER$' "$tmp/new.env")" 1
    if [ "$(sha256sum < "$tmp/keep.env")" = "$ks" ]; then echo "  PASS 6.24 기존 값 파일 불변"; else echo "  FAIL 6.24 기존 값 변경됨"; FAILS=$((FAILS+1)); fi
    assert_zero "6.24 .env 없음 → rc≠0" "$(grep -c '^rc_none=0$' "$tmp/rc")"
    # RV3-S-01 키 부재 → 같은 폴더 compose 의 :? 비밀 키만 추가(개행 없는 마지막 줄 보정), RV3-SEC-03 권한 600, 재실행 멱등
    mkdir -p "$tmp/dj" "$tmp/php" "$tmp/dup" "$tmp/crlf" "$tmp/nossl/bin"
    cp compose/web_service/nginx_gunicorn/docker-compose.yml "$tmp/dj/"; cp compose/web_service/nginx_php/docker-compose.yml "$tmp/php/"
    printf 'PROJECT_DIR=django_sample' > "$tmp/dj/.env"; printf 'PHP_X=1\n' > "$tmp/php/.env"; chmod 644 "$tmp/dj/.env" "$tmp/php/.env"
    # RV3-SEC-01 중복 키 — 기존 값 줄 보존, 빈 줄만 채움 / CRLF — CR 무시 매칭·줄끝 보존
    printf 'REDIS_PASSWORD=keep-redis\nREDIS_PASSWORD=\n' > "$tmp/dup/.env"
    printf 'DJANGO_SECRET_KEY=\r\nREDIS_PASSWORD=CHANGE_ME_X\r\nFLOWER_PWD=keep\r\n' > "$tmp/crlf/.env"
    # RV3-SEC-02 openssl 실패 → rc 1·파일 무변경
    printf '#!/bin/sh\nexit 1\n' > "$tmp/nossl/bin/openssl"; chmod +x "$tmp/nossl/bin/openssl"
    printf 'DJANGO_SECRET_KEY=\n' > "$tmp/nossl/.env"; ns=$(sha256sum < "$tmp/nossl/.env")
    ( . script/lib/django_secrets.sh
      for d in dj php dup crlf; do ensure_env_secrets "$tmp/$d/.env" >/dev/null; done
      sha256sum < "$tmp/dj/.env" > "$tmp/dj.sha"; ensure_env_secrets "$tmp/dj/.env" >/dev/null
      PATH="$tmp/nossl/bin:$PATH" ensure_env_secrets "$tmp/nossl/.env" >/dev/null 2>&1; echo "rc_nossl=$?" > "$tmp/rc2" )
    assert_eq   "6.24 키 부재 → 기존 줄 보존·3 키 추가 (RV3-S-01)" "$(grep -cE '^(PROJECT_DIR=django_sample|DJANGO_SECRET_KEY=[0-9a-f]{100}|REDIS_PASSWORD=[0-9a-f]{64}|FLOWER_PWD=[0-9a-f]{64})$' "$tmp/dj/.env")" 4
    assert_eq   "6.24 php 스택 키 부재 → REDIS_PASSWORD 만 추가" "$(grep -cE '^(REDIS_PASSWORD=[0-9a-f]{64}|DJANGO_SECRET_KEY=.*|FLOWER_PWD=.*)$' "$tmp/php/.env")" 1
    assert_eq   "6.24 생성 후 권한 600 (RV3-SEC-03)" "$(stat -c %a "$tmp/dj/.env" "$tmp/php/.env" | grep -c '^600$')" 2
    if [ "$(sha256sum < "$tmp/dj/.env")" = "$(cat "$tmp/dj.sha")" ]; then echo "  PASS 6.24 재실행 멱등(값 불변)"; else echo "  FAIL 6.24 재실행 시 값 변경"; FAILS=$((FAILS+1)); fi
    assert_eq   "6.24 중복 키 기존 값 줄 보존 (RV3-SEC-01)" "$(grep -c '^REDIS_PASSWORD=keep-redis$' "$tmp/dup/.env")" 1
    assert_eq   "6.24 중복 키 빈 줄만 생성" "$(grep -cE '^REDIS_PASSWORD=[0-9a-f]{64}$' "$tmp/dup/.env")" 1
    assert_eq   "6.24 CRLF 빈 값·CHANGE_ME 생성·기존 값 보존·줄끝 보존" "$(grep -cE $'^(DJANGO_SECRET_KEY=[0-9a-f]{100}|REDIS_PASSWORD=[0-9a-f]{64}|FLOWER_PWD=keep)\r$' "$tmp/crlf/.env")" 3
    assert_eq   "6.24 openssl 실패 → rc 1 (RV3-SEC-02)" "$(grep -c '^rc_nossl=1$' "$tmp/rc2")" 1
    if [ "$(sha256sum < "$tmp/nossl/.env")" = "$ns" ]; then echo "  PASS 6.24 openssl 실패 시 파일 무변경"; else echo "  FAIL 6.24 openssl 실패 시 파일 변경됨"; FAILS=$((FAILS+1)); fi
    # R4-01 쓰기 원자성 — 같은 폴더 임시 파일 + mv 교체: 쓰기 실패(읽기 전용 폴더) 시 rc 1·원본 불변·임시 파일 잔존 0
    #        심볼릭 링크 .env — 링크는 유지하고 대상 파일을 갱신
    mkdir -p "$tmp/ro" "$tmp/ln" "$tmp/real"
    printf 'DJANGO_SECRET_KEY=\n' > "$tmp/ro/.env"; rs=$(sha256sum < "$tmp/ro/.env"); chmod 555 "$tmp/ro"
    printf 'DJANGO_SECRET_KEY=\n' > "$tmp/real/env"; ln -s "$tmp/real/env" "$tmp/ln/.env"
    ( . script/lib/django_secrets.sh
      ensure_env_secrets "$tmp/ro/.env" >/dev/null 2>&1; echo "rc_ro=$?" > "$tmp/rc3"
      ensure_env_secrets "$tmp/ln/.env" >/dev/null 2>&1 )
    if [ "$(id -u)" -eq 0 ]; then echo "  SKIP 6.24 읽기 전용 폴더 쓰기 실패 (root 는 권한 무시)"; else
        assert_eq "6.24 쓰기 실패 → rc 1 (R4-01)" "$(grep -c '^rc_ro=1$' "$tmp/rc3")" 1
        if [ "$(sha256sum < "$tmp/ro/.env")" = "$rs" ]; then echo "  PASS 6.24 쓰기 실패 시 원본 sha 불변 (R4-01)"; else echo "  FAIL 6.24 쓰기 실패 시 원본 변경됨"; FAILS=$((FAILS+1)); fi
        assert_eq "6.24 쓰기 실패 시 임시 파일 잔존 없음" "$(find "$tmp/ro" -mindepth 1 | wc -l)" 1
    fi
    chmod 755 "$tmp/ro"
    assert_eq "6.24 심볼릭 링크 .env 링크 유지·대상 파일 생성 (R4-01)" "$( { [ -L "$tmp/ln/.env" ] && grep -cE '^DJANGO_SECRET_KEY=[0-9a-f]{100}$' "$tmp/real/env"; } || echo 0)" 1
    assert_eq "6.24 원자 교체 후 폴더 임시 파일 잔존 없음" "$(find "$tmp/dj" "$tmp/real" -name '*.env.*' -o -name 'env.*' | wc -l)" 0
    # R2S-02 docker-compose*.yml 전부의 :? 필수 키 합집합 중 비밀 이름(SECRET·PASSWORD·PWD 포함, _KEY_BASE 끝)만 채움/추가
    #        비밀 아닌 필수 키·주석 줄 키는 손대지 않음, _KEY_BASE 는 128 hex
    mkdir -p "$tmp/multi"
    printf 'services:\n  op:\n    environment:\n      - SECRET_KEY_BASE=${OPENPROJECT_SECRET_KEY_BASE:?set}\n      - HOST=${OPENPROJECT_HOST__NAME:?set}\n      - R=${REDIS_PASSWORD:?}\n      - D=${PROJECT_DIR:?} F=${FLOWER_ID:?}\n      # - C=${COMMENTED_PASSWORD:?}\n' > "$tmp/multi/docker-compose-foo.yml"
    printf 'services:\n  db:\n    environment:\n      - P=${BAR_DB_PASSWORD:?}\n      - A=${DJANGO_ALLOWED_HOSTS:?}\n' > "$tmp/multi/docker-compose-bar.yml"
    printf 'FLOWER_ID=\nOPENPROJECT_HOST__NAME=\nBAR_DB_PASSWORD=CHANGE_ME_X\n' > "$tmp/multi/.env"
    ( . script/lib/django_secrets.sh; ensure_env_secrets "$tmp/multi/.env" >/dev/null 2>&1 )
    assert_eq "6.24 docker-compose-foo.yml _KEY_BASE 부재 → 128 hex 추가 (R2S-02)" "$(grep -cE '^OPENPROJECT_SECRET_KEY_BASE=[0-9a-f]{128}$' "$tmp/multi/.env")" 1
    assert_eq "6.24 docker-compose-foo.yml REDIS_PASSWORD 부재 → 64 hex 추가 (R2S-02)" "$(grep -cE '^REDIS_PASSWORD=[0-9a-f]{64}$' "$tmp/multi/.env")" 1
    assert_eq "6.24 여러 compose 합집합 — bar 의 CHANGE_ME 비밀 채움 (R2S-02)" "$(grep -cE '^BAR_DB_PASSWORD=[0-9a-f]{64}$' "$tmp/multi/.env")" 1
    assert_eq "6.24 비밀 아닌 필수 키 빈 값 불변 (FLOWER_ID·OPENPROJECT_HOST__NAME)" "$(grep -cE '^(FLOWER_ID|OPENPROJECT_HOST__NAME)=$' "$tmp/multi/.env")" 2
    assert_zero "6.24 비밀 아닌·주석·compose 미요구 키 추가 없음" "$(grep -cE '^(PROJECT_DIR|DJANGO_ALLOWED_HOSTS|COMMENTED_PASSWORD|DJANGO_SECRET_KEY|FLOWER_PWD)=' "$tmp/multi/.env")"
    assert_eq "6.24 compose 여러 개 — 총 줄 수 (3 기존 + 2 추가)" "$(wc -l < "$tmp/multi/.env")" 5
    # RV7-01 원본 644 여도 비밀이 담긴 임시 파일은 어느 chmod 직후에도 group/other 비트 0 — chmod 래퍼가 매 호출 뒤 임시 파일 권한 기록
    # 잔여 위험 6 인터럽트(TERM) 시 임시 파일(비밀 포함) 정리·원본 불변 — mv 래퍼가 자기 자신에게 TERM
    mkdir -p "$tmp/perm" "$tmp/intr"
    printf 'DJANGO_SECRET_KEY=\n' > "$tmp/perm/.env"; chmod 644 "$tmp/perm/.env"
    printf 'DJANGO_SECRET_KEY=\n' > "$tmp/intr/.env"; is=$(sha256sum < "$tmp/intr/.env")
    ( . script/lib/django_secrets.sh; s6_pdir="$tmp/perm" s6_plog="$tmp/perm.log"   # 헬퍼 local tmp 와 겹치지 않는 이름(동적 스코프)
      chmod() { command chmod "$@"; local r=$?; stat -c %a "$s6_pdir"/.env.?????? >> "$s6_plog" 2>/dev/null; return $r; }
      ensure_env_secrets "$tmp/perm/.env" >/dev/null 2>&1 )
    bash -c '. script/lib/django_secrets.sh; mv() { kill -TERM $$; }; ensure_env_secrets "$1"' _ "$tmp/intr/.env" >/dev/null 2>&1
    assert_eq   "6.24 임시 파일 권한 관측됨 (RV7-01)" "$( [ -s "$tmp/perm.log" ] && echo 1 || echo 0)" 1
    assert_zero "6.24 임시 파일 중간 권한 go 비트 ≠0 (RV7-01)" "$(grep -cvE '^[0-7]00$' "$tmp/perm.log" 2>/dev/null)"
    assert_eq   "6.24 원본 644 → 생성 후 600 (RV7-01)" "$(stat -c %a "$tmp/perm/.env")" 600
    assert_zero "6.24 인터럽트 시 임시 파일 잔존 (잔여 위험 6)" "$(find "$tmp/intr" -name '.env.*' | wc -l)"
    if [ "$(sha256sum < "$tmp/intr/.env")" = "$is" ]; then echo "  PASS 6.24 인터럽트 시 원본 sha 불변"; else echo "  FAIL 6.24 인터럽트 시 원본 변경됨"; FAILS=$((FAILS+1)); fi
    rm -rf "$tmp"
else
    echo "  FAIL 6.24 ensure_env_secrets 없음"; FAILS=$((FAILS+1))
fi
for s in gunicorn uvicorn uwsgi daphne php; do
    assert_eq "6.24 .env-example 한 줄 생성 안내 ($s)" "$(grep -c "ensure_env_secrets compose/web_service/nginx_$s/.env" compose/web_service/nginx_$s/.env-example)" 1
done
# 잔여 위험 6: 강제 종료(KILL)로 남은 헬퍼 임시 파일 .env.XXXXXX 는 무시, .env-example·.env.example 은 추적 유지
d=compose/web_service/nginx_gunicorn
assert_eq "6.24 .gitignore .env.XXXXXX 무시·.env-example/.env.example 비무시" "$(git check-ignore --no-index "$d/.env.Ab12Cd" "$d/.env-example" "$d/.env.example" 2>/dev/null | grep -cxF "$d/.env.Ab12Cd")" 1
assert_zero "6.24 .gitignore .env-example/.env.example 무시됨" "$(git check-ignore --no-index "$d/.env-example" "$d/.env.example" 2>/dev/null | wc -l)"
assert_eq "6.24 .gitignore 예외 규칙 표기가 추적 파일명 .env-example 과 일치 (CL-WP5-04)" "$(grep -cxF '!**/.env-example' .gitignore)" 1
assert_zero "6.24 git check-ignore 로 무시되는 추적 .env-example (CL-WP5-04)" "$(git ls-files -z '*.env-example' | git check-ignore --no-index -z --stdin | tr -cd '\0' | wc -c)"
echo

echo "===== 6.29 compose 가 :? 로 요구하는 비밀 키는 .env-example 에서 빈 값 — 공개 예시 자격증명 금지 (3회차 13) ====="
for d in compose/web_service/nginx_*; do
    for k in $(grep -oE '\$\{[A-Z_]*(PASSWORD|PWD|SECRET|TOKEN|_KEY)[A-Z_]*:\?' "$d/docker-compose.yml" | sed -E 's/\$\{([A-Z_]+):\?/\1/' | sort -u); do
        v=$(grep -E "^$k=" "$d/.env-example" | head -1 | cut -d= -f2-)
        if grep -qE "^$k=" "$d/.env-example" && [ -z "$v" ]; then echo "  PASS 6.29 $d $k 빈 값"; else echo "  FAIL 6.29 $d $k=[$v]"; FAILS=$((FAILS+1)); fi
    done
done
echo

echo "===== 6.25 CI 경로에서 celery·beat 를 --profile celery 로 기동해 안정성 판정 (RV2-S-03) ====="
f=script/test_run/verify_integration_gunicorn.sh
assert_eq "6.25 --profile celery 기동" "$(grep -c -- '--profile celery up -d --wait' "$f")" 1
assert_eq "6.25 celery·celery-beat containers_stable" "$(grep -c 'containers_stable "$(dc --profile celery ps -q celery)" "$(dc --profile celery ps -q celery-beat)"' "$f")" 1
assert_eq "6.25 정리 시 celery 프로파일 포함 down" "$(grep -c 'dc --profile celery down -v' "$f")" 1
assert_eq "6.25 celery 워커 브로커 응답 판정 inspect ping (컨테이너 내부·dc 래퍼)" "$(grep -c 'dc --profile celery exec -T celery celery -A config inspect ping' "$f")" 1
echo

echo "===== 6.26 하네스는 운영 공유 이미지 태그를 덮어쓰지 않음 — IMAGE_NAMESPACE (RV2-SEC-03) ====="
for s in gunicorn uvicorn uwsgi daphne php; do
    assert_zero "6.26 고정 devspoon 이미지명 ($s)" "$(grep -cE '^[[:space:]]+image: devspoon-' compose/web_service/nginx_$s/docker-compose.yml)"
done
for f in script/test_run/verify_integration_*.sh script/test_run/verify_healthcheck.sh script/test/verify-ngxblocker.sh; do
    assert_eq "6.26 테스트 이미지 네임스페이스 ($f)" "$(grep -c 'IMAGE_NAMESPACE=devspoon-it' "$f")" 1
done
echo

echo "===== 6.27 공용 nginx.conf 가 proxy.d/*/*.conf 를 zone·map 뒤, conf.d 앞에서 include (SRV1-S-02) ====="
for f in config/web-server/nginx/{gunicorn,uvicorn,uwsgi,php}/nginx_conf/nginx.conf; do
    i=$(grep -nE '^[[:space:]]*include[[:space:]]+/etc/nginx/proxy\.d/\*/\*\.conf;' "$f" | cut -d: -f1); z=$(grep -n 'map $http_upgrade $connection_upgrade' "$f" | cut -d: -f1); c=$(grep -nE '^[[:space:]]*include[[:space:]]+/etc/nginx/conf\.d/\*\.conf;' "$f" | cut -d: -f1)
    if [ -n "$i" ] && [ "$(grep -cE '^[[:space:]]*include[[:space:]]+/etc/nginx/proxy\.d/' "$f")" = 1 ] && [ "$i" -gt "$z" ] && [ "$i" -lt "$c" ]; then echo "  PASS 6.27 ($f)"; else echo "  FAIL 6.27 ($f) proxy.d=$i map=$z conf.d=$c"; FAILS=$((FAILS+1)); fi
done
echo

echo "===== 6.28 생성기 안내·.env-example 문구가 저장소 중립·실제 설정과 일치 (SRV1-S-04, SRV1-SEC-05) ====="
assert_zero "6.28 생성기의 compose/web-service·web_service 고정 경로" "$(cat config/web-server/nginx/*/nginx_http*_conf.sh | grep -cE 'compose/web[-_]service')"
for s in gunicorn uvicorn uwsgi daphne; do
    assert_zero "6.28 flower '외부에 노출' 문구 ($s)" "$(grep -c '외부에 노출' compose/web_service/nginx_$s/.env-example)"
done
echo

echo "===== 6.31 run-ci 스택 뒤 호스트 소스 트리 소유권 런타임 단언, compose :? 필수 키 개별 빈 값 거부 (P6, P2) ====="
assert_eq "6.31 run-ci find www ! -user" "$(grep -cF 'find "$ROOT/www" ! -user "$(id -u)"' script/ci/run-ci.sh)" 1
assert_eq "6.31 verify_compose_yml :? 필수 키 개별 빈 값 거부" "$(grep -c '\[PASS\] :? 필수 키 개별 빈 값 거부' script/test_run/verify_compose_yml.sh)" 1
echo

echo "===== 6.32 검증기 HTTP 단언 전 준비 대기(wait_http)·실패 시 실제 코드 출력(http_is) (CL-WP4-R9-FLAKY) ====="
for f in script/test_run/verify_integration_*.sh script/test/verify-ngxblocker.sh; do
    w=$(grep -n 'wait_http ' "$f" | head -1 | cut -d: -f1); h=$(grep -nE 'http_is |정상 UA → 200' "$f" | grep -v wait_http | head -1 | cut -d: -f1)
    if [ -n "$w" ] && [ -n "$h" ] && [ "$w" -lt "$h" ]; then echo "  PASS 6.32 준비 대기가 첫 HTTP 단언보다 앞 ($f)"; else echo "  FAIL 6.32 준비 대기 없음·순서 ($f) wait_http=$w 첫단언=$h"; FAILS=$((FAILS+1)); fi
done
for f in script/test_run/verify_integration_*.sh; do
    assert_zero "6.32 코드 미출력 단언 \"\$(code ...)\" = N ($f)" "$(grep -c '"$(code ' "$f")"
done
if [ -f script/lib/stability.sh ] && . script/lib/stability.sh && declare -F wait_http >/dev/null; then
    out=$(WAIT_HTTP_TRIES=2 WAIT_HTTP_INTERVAL=0 wait_http 200 --max-time 1 http://127.0.0.1:9/); rc=$?
    if [ "$rc" != 0 ] && [[ "$out" == *"HTTP 000"* ]]; then echo "  PASS 6.32 영구 거부 → 상한 후 FAIL·마지막 코드 출력"; else echo "  FAIL 6.32 영구 거부 rc=$rc out=[$out]"; FAILS=$((FAILS+1)); fi
else
    echo "  FAIL 6.32 stability.sh 에 wait_http 없음"; FAILS=$((FAILS+1))
fi
echo

echo "===== 6.33 봇 UA 차단 단언은 curl exit 52(응답 없이 닫힘)·444 만 PASS — 연결 거부 등 코드 000 은 FAIL (TST-R10-01) ====="
for f in script/test_run/verify_integration_*.sh; do
    # 옛 판정 문자열 `=~ ^(000|444)$`(ad95ff0)·`http_is "000|444"`(5ce6de1^) 둘 다 `000|444` 를 포함 (REV-W13-01)
    assert_zero "6.33 코드 000 허용 봇 단언 ($f)" "$(grep -cF '000|444' "$f")"
    assert_eq   "6.33 http_blocked 봇 단언 ($f)" "$(grep -c 'http_blocked -A MJ12bot' "$f")" 1
done
assert_zero "6.33 verify-ngxblocker 코드 000 허용" "$(grep -c '"000"' script/test/verify-ngxblocker.sh)"
assert_eq   "6.33 임시 서버·파일 정리 trap (REV-W13-10)" "$(grep -cE "^[[:space:]]+trap '[^']*kill [^']*rm -f [^']*' INT TERM" script/test_run/s6_regression.sh)" 1
# 로컬 임시 서버: close = 요청 읽고 응답 없이 닫음(nginx return 444 모사), 200 = 정상 응답
srv_py='import socket,sys
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1); s.bind(("127.0.0.1",0)); s.listen(8)
print(s.getsockname()[1],flush=True)
while True:
    c,_=s.accept(); c.recv(65536)
    if sys.argv[1]=="200": c.sendall(b"HTTP/1.0 200 OK\r\nContent-Length: 0\r\n\r\n")
    c.close()'
blk_case() {  # blk_case <라벨> <기대 rc 0|1> <출력 포함 문자열> <url>
    local out rc; out=$(http_blocked -A MJ12bot --max-time 3 "$4"); rc=$?; [ "$rc" != 0 ] && rc=1
    if [ "$rc" = "$2" ] && [[ "$out" == *"$3"* ]]; then echo "  PASS 6.33 $1"; else echo "  FAIL 6.33 $1 rc=$rc out=[$out]"; FAILS=$((FAILS+1)); fi
}
if . script/lib/stability.sh && declare -F http_blocked >/dev/null; then
    t1=$(mktemp); t2=$(mktemp); p1=; p2=
    # 중단(Ctrl-C·CI 취소) 시에도 서버·임시 파일 정리 — 비대화형 셸의 백그라운드 작업은 SIGINT 를 무시하므로 남는다 (REV-W13-10)
    trap 'kill $p1 $p2 2>/dev/null; rm -f "$t1" "$t2"; exit 130' INT TERM
    python3 -c "$srv_py" close >"$t1" & p1=$!
    python3 -c "$srv_py" 200 >"$t2" & p2=$!
    for _ in $(seq 50); do [ -s "$t1" ] && [ -s "$t2" ] && break; sleep 0.1; done
    blk_case "연결 거부(exit 7) → FAIL·실제 exit 출력" 1 "exit 7" http://127.0.0.1:9/
    blk_case "응답 없이 닫힘(exit 52) → PASS" 0 "" "http://127.0.0.1:$(cat "$t1")/"
    blk_case "정상 200 → FAIL·실제 코드 출력" 1 "HTTP 200" "http://127.0.0.1:$(cat "$t2")/"
    kill "$p1" "$p2" 2>/dev/null; wait "$p1" "$p2" 2>/dev/null; rm -f "$t1" "$t2"; trap - INT TERM
else
    echo "  FAIL 6.33 stability.sh 에 http_blocked 없음"; FAILS=$((FAILS+1))
fi
echo

echo "===== 6.34 s3 봇 UA 차단 판정도 http_blocked — 코드 000(연결 거부 exit 7 등) 허용 금지 (TST-R11-01) ====="
f=script/test_run/s3_stack_smoke.sh
assert_zero "6.34 s3 봇 UA 코드 000 허용 판정 (3B.8·3B.8a)" "$(grep -cE '= "000" \] (&& pass "3B\.8|\|\| all_blocked)' "$f")"
assert_eq   "6.34 s3 stability.sh source" "$(grep -cxF '. "$ROOT/script/lib/stability.sh"' "$f")" 1
assert_eq   "6.34 s3 http_blocked 봇 단언 (3B.8·3B.8a)" "$(grep -cE '^[[:space:]]*out=\$\(http_blocked -A "(MJ12bot|\$ua)"' "$f")" 2
# REV-W13-03: 실패 사유 = 헬퍼 실제 출력(curl exit·코드) — 고정 문구면 SUMMARY 로 거부/타임아웃/미차단 구분 불가
assert_eq   "6.34 s3 차단 판정 실패 사유에 헬퍼 출력 (3B.6·3B.8·3B.8a)" "$(grep -cE 'fail "3B\.(6|8)" "\$out"$|fail "3B\.8a" "\$why"$' "$f")" 3
# TST-R12-01: 3B.6 Host 조작도 default_server `return 444` 차단 — 000 을 PASS 로 인정하는 판정 전면 금지
assert_zero "6.34 s3 코드 000 을 PASS 로 인정하는 판정 (3B.6 포함)" "$(grep -cE '"000" \] && pass' "$f")"
assert_eq   "6.34 s3 http_blocked Host 조작 단언 (3B.6)" "$(grep -cE '^out=\$\(http_blocked -H "Host: evil\.com" .*&& pass "3B\.6"' "$f")" 1
echo

echo "===== 6.35 s3 판정은 rc·전체 출력, 기대 버전·필수 키는 저장소 원천(uv.lock·스택 .env-example)에서 도출 (TST-R13-01~03) ====="
f=script/test_run/s3_stack_smoke.sh
assert_zero "6.35 s3 잘린 출력(tail/head)을 캡처해 판정" "$(grep -cE '=\$\([^)]*\| *(tail|head) +-[0-9]+\)' "$f")"
assert_zero "6.35 s3 하드코딩 버전 문자열 판정" "$(grep -cE 'grep -qF? "?[0-9]+\.[0-9]+\.[0-9]+' "$f")"
assert_zero "6.35 s3 스택 공통 필수 키 목록 (need_vars)" "$(grep -c 'need_vars=(' "$f")"
assert_eq   "6.35 s3 3B.15 rc·전체 출력 판정" "$(grep -c 'logrotate_dry_ok "\$rc" "\$out" && pass "3B\.15"' "$f")" 1
assert_eq   "6.35 s3 3C Django 기대 버전 = uv.lock" "$(grep -c 'lock_version django ' "$f")" 1
assert_eq   "6.35 s3 3C Django 스택 분기에 daphne 포함" "$(grep -cE '^[[:space:]]+gunicorn\|uvicorn\|daphne\)' "$f")" 1
assert_zero "6.35 s3 프로젝트명 하드코딩 (3C.uwsgi 로그 = .env PROJECT_DIR)" "$(grep -c 'django_sample' "$f")"
assert_eq   "6.35 s3 3B.1 필수 키 = 스택 .env-example" "$(grep -c 'env_missing .env-example .env' "$f")" 1
u35() { if [ "$2" = "$3" ]; then echo "  PASS 6.35 $1"; else echo "  FAIL 6.35 $1 (got [$2], expected [$3])"; FAILS=$((FAILS+1)); fi; }
unset -f logrotate_dry_ok lock_version env_missing
# REV-W16-01: 표지가 빠지면 sed 범위가 파일 끝까지 가서 s3 뒷부분(docker·curl·exit)을 eval 한다 — 시작·끝 표지가 각 1개일 때만 추출
[ "$(grep -c '^# >>> s3 순수 판정' "$f")" = 1 ] && [ "$(grep -c '^# <<< s3 순수 판정' "$f")" = 1 ] &&
    eval "$(sed -n '/^# >>> s3 순수 판정/,/^# <<< s3 순수 판정/p' "$f")"
if declare -F logrotate_dry_ok >/dev/null && declare -F lock_version >/dev/null && declare -F env_missing >/dev/null; then
    # 실측 logrotate 3.21.0 `-d /run/logrotate.d/nginx` 출력 발췌 (sw 4회차 part A) — Handling 행은 8행, tail -5 창 밖
    lr=$(cat <<'EOF'
warning: logrotate in debug mode does nothing except printing debug messages!  Consider using verbose mode (-v) instead if this is not what you want.

reading config file /run/logrotate.d/nginx
note: 'size' overrides previously specified 'daily'
Reading state from file: /var/lib/logrotate/status
Allocating hash table for state file, size 64 entries

Handling 1 logs

rotating pattern: /log/nginx/*.log  104857600 bytes (30 rotations)
empty log files are not rotated, old logs are removed
considering log /log/nginx/django_sample.com.gunicorn_access_http.log
Creating new state
  Now: 2026-09-15 21:20
  Last rotated at 2026-09-15 21:00
  log does not need rotating (log size is below the 'size' threshold)
considering log /log/nginx/sample.com.php_error_http.log
Creating new state
  Now: 2026-09-15 21:20
  Last rotated at 2026-09-15 21:00
  log does not need rotating (log size is below the 'size' threshold)
not running postrotate script, since no logs were rotated
EOF
)
    u35 "3B.15 실측 출력 rc 0 → PASS" "$(logrotate_dry_ok 0 "$lr" && echo PASS || echo FAIL)" PASS
    u35 "3B.15 rc 1 → FAIL" "$(logrotate_dry_ok 1 "$lr" && echo PASS || echo FAIL)" FAIL
    u35 "3B.15 옛 tail -5 창(Handling 행 없음) → FAIL" "$(logrotate_dry_ok 0 "$(tail -5 <<<"$lr")" && echo PASS || echo FAIL)" FAIL
    u35 "3B.15 Handling 0 logs → FAIL" "$(logrotate_dry_ok 0 "${lr/Handling 1 logs/Handling 0 logs}" && echo PASS || echo FAIL)" FAIL
    t=$(mktemp -d)
    printf '[[package]]\nname = "django-celery-beat"\nversion = "2.9.0"\n\n[[package]]\nname = "django"\nversion = "6.0.7"\n' > "$t/uv.lock"
    u35 "3C uv.lock 정확한 패키지명 버전 (django-celery-beat 무시)" "$(lock_version django "$t/uv.lock")" 6.0.7
    u35 "3C 저장소 www/django_sample/uv.lock Django 버전 도출" "$(lock_version django www/django_sample/uv.lock | grep -cE '^[0-9]+\.[0-9]+(\.[0-9]+)?$')" 1
    for ex in compose/web[-_]service/nginx_php*/.env-example; do
        grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$ex" | sed 's/$/x/' > "$t/php.env"   # php .env-example 키만 가진 .env
        u35 "3B.1 php .env-example 키만 → 누락 0 ($ex)" "$(env_missing "$ex" "$t/php.env"; echo "rc=$?")" "rc=0"
        u35 "3B.1 같은 .env 를 gunicorn 기준으로 → FLOWER_ID 누락 보고 ($ex)" "$(env_missing compose/web[-_]service/nginx_gunicorn/.env-example "$t/php.env" | grep -cw FLOWER_ID)" 1
    done
    : > "$t/empty"
    u35 "3B.1 .env-example 키 0 → 실패 rc 1" "$(env_missing "$t/empty" "$t/php.env" >/dev/null; echo $?)" 1
    rm -rf "$t"
else
    echo "  FAIL 6.35 s3 순수 판정 블록(logrotate_dry_ok·lock_version·env_missing) 없음"; FAILS=$((FAILS+1))
fi
echo

echo "===== 6.36 verify-ngxblocker 스택 기동은 --build — 공유 태그에 남은 옛 이미지 검증 금지 (TST-R16-01) ====="
f=script/test/verify-ngxblocker.sh
assert_zero "6.36 --build 없는 compose up ($f)" "$(grep -E '^[[:space:]]*(dc|docker compose)( [^#]*)? up( |$)' "$f" | sed 's/[[:space:]]#.*//' | grep -cv -- '--build')"
assert_eq   "6.36 dc up -d --build webserver redis ($f)" "$(grep -cE '^[[:space:]]*dc up -d --build webserver redis( |$)' "$f")" 1
echo

echo "===== 6 FAILS=$FAILS ====="
# 실패가 있으면 non-zero 로 종료 → CI / 상위 스크립트가 $? 로 판정 가능.
[ "$FAILS" -eq 0 ]
exit $?
