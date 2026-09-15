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
n=$(find . -type f -not -path './.git/*' -not -path './.claude/*' -not -path './log/*' -not -path './www/*/.venv/*' 2>/dev/null | xargs file 2>/dev/null | grep -i CRLF | wc -l)
echo "  (first 10 if any):"
find . -type f -not -path './.git/*' -not -path './.claude/*' -not -path './log/*' -not -path './www/*/.venv/*' 2>/dev/null | xargs file 2>/dev/null | grep -i CRLF | head -10
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

echo "===== 6.19 앱 이미지 사전설치 버전 = django_sample uv.lock (기동마다 uv sync 재설치 방지) ====="
lockv() { awk -v n="$1" '$0 == "name = \"" n "\"" { getline; gsub(/"/, "", $3); print $3; exit }' "${2:-www/django_sample/uv.lock}"; }
for spec in "docker/gunicorn/Dockerfile gunicorn" "docker/gunicorn/Dockerfile uvicorn" "docker/uwsgi/Dockerfile gunicorn" "docker/uwsgi/Dockerfile uvicorn" "docker/uwsgi/Dockerfile uwsgi" "docker/uwsgi/Dockerfile django"; do
    df=${spec% *}; pkg=${spec#* }
    want=$(lockv "$pkg"); got=$(grep -oE "(^|[[:space:]\"])$pkg(\[standard\])?==[0-9][0-9.]*" "$df" | head -1 | sed 's/.*==//')
    if [ -n "$want" ] && [ "$want" = "$got" ]; then echo "  PASS 6.19 $df $pkg==$got"; else echo "  FAIL 6.19 $df $pkg image=[$got] lock=[$want]"; FAILS=$((FAILS+1)); fi
done
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

echo "===== 6.22 Django migrate 는 app 서비스에서만 기동 전 1회, celery·beat 는 app healthy 뒤 기동 (CL-WP1-08-R2b) ====="
for s in gunicorn uvicorn uwsgi daphne; do
    f=compose/web_service/nginx_$s/docker-compose.yml
    assert_eq "6.22 migrate 1회(app 만) ($s)" "$(grep -c 'manage.py migrate --noinput' "$f")" 1
    assert_eq "6.22 uv sync → migrate → /data chown → 서버 순서 ($s)" "$(grep -cF '{ [ ! -f manage.py ] || python manage.py migrate --noinput; } && chown -R www-data:www-data /data && ' "$f")" 1
    assert_eq "6.22 ${s}-app service_healthy 의존 3곳(webserver·celery·beat) ($s)" "$(grep -A1 -E "^      ${s}-app:\$" "$f" | grep -c 'condition: service_healthy')" 3
done
echo

echo "===== 6.23 s5_https 는 출고 http 샘플과 겹치지 않는 도메인 + reload 후 준비 대기 (CL-WP4-08-R2) ====="
assert_zero "6.23 s5 -d localhost (출고 http 샘플 server_name 충돌)" "$(grep -c -- '-d localhost' script/test_run/s5_https.sh)"
n=$(grep -c 'S5_WAIT' script/test_run/s5_https.sh)
if [ "$n" -ge 2 ]; then echo "  PASS 6.23 s5 준비 대기 ($n)"; else echo "  FAIL 6.23 s5 준비 대기 없음"; FAILS=$((FAILS+1)); fi
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
    rm -rf "$tmp"
else
    echo "  FAIL 6.24 ensure_env_secrets 없음"; FAILS=$((FAILS+1))
fi
for s in gunicorn uvicorn uwsgi daphne php; do
    assert_eq "6.24 .env-example 한 줄 생성 안내 ($s)" "$(grep -c "ensure_env_secrets compose/web_service/nginx_$s/.env" compose/web_service/nginx_$s/.env-example)" 1
done
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

echo "===== 6 FAILS=$FAILS ====="
# 실패가 있으면 non-zero 로 종료 → CI / 상위 스크립트가 $? 로 판정 가능.
[ "$FAILS" -eq 0 ]
exit $?
