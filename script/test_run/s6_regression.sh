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
n=$(find . -type f -not -path './.git/*' -not -path './.claude/*' -not -path './log/*' -not -path './www/django_sample/.venv/*' 2>/dev/null | xargs file 2>/dev/null | grep -i CRLF | wc -l)
echo "  (first 10 if any):"
find . -type f -not -path './.git/*' -not -path './.claude/*' -not -path './log/*' -not -path './www/django_sample/.venv/*' 2>/dev/null | xargs file 2>/dev/null | grep -i CRLF | head -10
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

echo "===== 6.16 알림·아티팩트 비밀값 마스킹 (RV1-SEC-04) ====="
if [ -f script/lib/mask_secrets.sh ]; then
    # shellcheck source=../lib/mask_secrets.sh
    . script/lib/mask_secrets.sh
    leak=$(printf '%s\n' 'echo REDIS_PASSWORD=dummysecret' 'TELEGRAM_BOT_TOKEN: dummysecret' 'redis://:dummysecret@redis:6379/3' '{"SECRET_KEY": "dummysecret"}' 'FLOWER_BASIC_AUTH=tester:dummysecret' 'redis-server --requirepass dummysecret' 'Authorization: Bearer dummysecret' "DJANGO_SECRET_KEY='dummy secret'" 'FLOWER_PWD="dummy secret"' | mask_secrets | grep -c dummy)
    assert_zero "6.16 마스킹 샘플 9종 누출" "$leak"
else
    echo "  FAIL 6.16 script/lib/mask_secrets.sh 없음"; FAILS=$((FAILS+1))
fi
assert_eq "6.16 run-ci 알림 본문·로그 파일 마스킹 호출" "$(grep -cE '^[[:space:]]*mask_secrets_files[[:space:]]|\|[[:space:]]*mask_secrets\)' script/ci/run-ci.sh)" 2
echo

echo "===== 6.17 하네스는 운영 .env 를 수정·생성하지 않고 임시 env-file·전용 compose 프로젝트로 격리 (RV1-SEC-02) ====="
for f in script/test_run/verify_integration_*.sh script/test_run/verify_compose_yml.sh script/test_run/verify_healthcheck.sh script/test/verify-ngxblocker.sh; do
    w=$(grep -cE 'sed -i.*\.env|cp \.env-example \.env|>[[:space:]]*\.env([[:space:]]|$)' "$f"); e=$(grep -c -- '--env-file' "$f")
    if [ "$w" = 0 ] && [ "$e" -ge 1 ]; then echo "  PASS 6.17 ($f)"; else echo "  FAIL 6.17 ($f) env_write=$w env_file=$e"; FAILS=$((FAILS+1)); fi
done
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
    assert_eq   "6.18 containers_stable 사용 ($f)" "$(grep -c 'containers_stable ' "$f")" 1
    assert_zero "6.18 순간 RestartCount 판정 ($f)" "$(grep -c '{{.RestartCount}}' "$f")"
done
assert_eq   "6.18 verify_healthcheck B.2 containers_stable" "$(grep -c 'containers_stable ' script/test_run/verify_healthcheck.sh)" 1
assert_zero "6.18 verify_healthcheck 순간 running 0 판정" "$(grep -c '"running 0"' script/test_run/verify_healthcheck.sh)"
assert_eq   "6.18 verify_healthcheck 런타임 teardown trap (RV1-S-06)" "$(grep -cE "^trap 'dc .*down -v" script/test_run/verify_healthcheck.sh)" 1
echo

echo "===== 6.19 앱 이미지 사전설치 버전 = django_sample uv.lock (기동마다 uv sync 재설치 방지) ====="
lockv() { awk -v n="$1" '$0 == "name = \"" n "\"" { getline; gsub(/"/, "", $3); print $3; exit }' www/django_sample/uv.lock; }
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

echo "===== 6 FAILS=$FAILS ====="
# 실패가 있으면 non-zero 로 종료 → CI / 상위 스크립트가 $? 로 판정 가능.
[ "$FAILS" -eq 0 ]
exit $?
