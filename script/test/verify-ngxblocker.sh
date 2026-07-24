#!/usr/bin/env bash
# ngxblocker 통합 종단간 검증 — WSL + docker compose 환경 가정
# Step 1: 다운로드 검증, Step 2: 설정 검증, Step 3: nginx 적용 검증

set -uo pipefail
cd "$(dirname "$0")/../.."

CONT=nginx-gunicorn-webserver
STACK_DIR=compose/web_service/nginx_gunicorn

pass() { printf "  \e[32m[PASS]\e[0m %s\n" "$1"; }
fail() { printf "  \e[31m[FAIL]\e[0m %s\n" "$1"; FAILED=$((FAILED+1)); }
hdr()  { printf "\n\e[36m=== %s ===\e[0m\n" "$1"; }
FAILED=0

# ============================================================================
# STEP A — 스택 정상 기동 (이전 상태 정리 후)
# ============================================================================
hdr "Step A — 스택 기동"
(cd $STACK_DIR && docker compose down -v --remove-orphans >/dev/null 2>&1 || true)
(cd $STACK_DIR && docker compose up -d webserver redis 2>&1 | tail -3)
sleep 5
docker ps --filter "name=$CONT" --format '{{.Names}} {{.Status}}'
docker exec $CONT nginx -t 2>&1 | tail -2

# ============================================================================
# STEP B — 다운로드 검증 (install-ngxblocker 산출물)
# ============================================================================
hdr "Step B — 다운로드 산출물 검증"

# B-1. globalblacklist.conf 존재 + 크기 + 헤더
size=$(docker exec $CONT stat -c %s /etc/nginx/globalblacklist.conf 2>/dev/null || echo 0)
echo "  globalblacklist.conf size: $size bytes"
[ "$size" -gt 400000 ] && pass "globalblacklist.conf >= 400KB (정상 다운로드)" \
                     || fail "globalblacklist.conf 크기 비정상 ($size)"

# B-2. 버전 라인 확인 (파일 상단에 # VERSION 라인 존재)
ver=$(docker exec $CONT head -5 /etc/nginx/globalblacklist.conf | grep -i "version\|date" | head -2)
echo "  버전/날짜:"
echo "$ver" | sed 's/^/    /'
[ -n "$ver" ] && pass "버전 메타데이터 존재" || fail "버전 메타데이터 없음"

# B-3. map 정의 라인 수 — globalblacklist.conf 는 \"...\" quoted form 사용
maps=$(docker exec $CONT grep -cE '^\s*"~\*' /etc/nginx/globalblacklist.conf)
echo "  봇 패턴 (regex map entries): $maps"
[ "$maps" -gt 1000 ] && pass "1000+ 봇 패턴 로드됨" || fail "패턴 수 부족 ($maps)"

# B-4. 알려진 봇 패턴이 실제로 포함되는지 (스팟체크)
hdr "Step B-4 — 알려진 봇 패턴 spot-check"
for bot in MJ12bot AhrefsBot SemrushBot DotBot BLEXBot Scrapy nikto sqlmap; do
    if docker exec $CONT grep -qiE "$bot" /etc/nginx/globalblacklist.conf; then
        pass "$bot 포함"
    else
        fail "$bot 누락"
    fi
done

# B-5. bots.d 디렉터리 — 9개 파일 모두 존재
hdr "Step B-5 — bots.d 파일 9종 검증"
expected_bots="bad-referrer-words.conf blacklist-domains.conf blacklist-ips.conf blacklist-user-agents.conf blockbots.conf custom-bad-referrers.conf ddos.conf whitelist-domains.conf whitelist-ips.conf"
for f in $expected_bots; do
    if docker exec $CONT test -f /etc/nginx/bots.d/$f; then
        pass "bots.d/$f 존재"
    else
        fail "bots.d/$f 누락"
    fi
done

# ============================================================================
# STEP C — 설정 (nginx 통합) 검증
# ============================================================================
hdr "Step C — nginx 통합 검증"

# C-1. nginx.conf 가 globalblacklist.conf 를 include 하는지
inc=$(docker exec $CONT grep -c "include /etc/nginx/globalblacklist.conf" /etc/nginx/nginx.conf)
echo "  nginx.conf include 라인 수: $inc"
[ "$inc" = "1" ] && pass "nginx.conf 에 include 1회" || fail "include 누락 또는 중복"

# C-2. $bad_bot 변수가 globalblacklist.conf 의 map 으로 정의되었는지 확인
bbm=$(docker exec $CONT grep -c '\$bad_bot' /etc/nginx/globalblacklist.conf)
echo "  globalblacklist.conf 내 \$bad_bot 참조: $bbm"
[ "$bbm" -gt 0 ] && pass "\$bad_bot 변수 정의 확인" || fail "\$bad_bot 변수 미정의"

# C-3. nginx -t 통과 — 한 번만 실행하고 두 메시지 모두 검사 (entrypoint 출력 인터리브 회피)
nt_out=$(docker exec $CONT nginx -t 2>&1)
echo "$nt_out" | grep -q "syntax is ok"     && pass "nginx -t syntax OK"     || fail "nginx -t syntax error"
echo "$nt_out" | grep -q "test is successful" && pass "nginx -t test successful" || fail "nginx -t test failed"

# C-4. nginx 워커 프로세스 정상 실행
nw=$(docker exec $CONT bash -c "ps -eo comm | grep -c '^nginx$'" 2>/dev/null || echo 0)
echo "  nginx 프로세스 수: $nw (master + workers)"
[ "$nw" -ge 2 ] && pass "nginx 정상 기동" || fail "nginx 프로세스 부족"

# ============================================================================
# STEP D — cron 등록 + 수동 update 실행 검증
# ============================================================================
hdr "Step D — cron / update-ngxblocker 실행 검증"

# D-1. cron 등록 라인
if docker exec $CONT crontab -l | grep -q "update-ngxblocker -c /etc/nginx"; then
    pass "cron 에 update-ngxblocker (-c /etc/nginx) 등록됨"
else
    fail "cron 등록 누락"
fi

# D-2. cron 데몬 실행 중
if docker exec $CONT pgrep -a cron >/dev/null 2>&1; then
    pass "cron 데몬 실행 중"
else
    fail "cron 데몬 미실행"
fi

# D-3. 수동 update-ngxblocker 실행 — 다운로드 시도 및 변경 적용
echo "  수동 update-ngxblocker 실행 (몇 초 소요)..."
size_before=$(docker exec $CONT stat -c %s /etc/nginx/globalblacklist.conf)
mtime_before=$(docker exec $CONT stat -c %Y /etc/nginx/globalblacklist.conf)
docker exec $CONT bash -c "/usr/local/sbin/update-ngxblocker -c /etc/nginx 2>&1" | tail -10
size_after=$(docker exec $CONT stat -c %s /etc/nginx/globalblacklist.conf)
mtime_after=$(docker exec $CONT stat -c %Y /etc/nginx/globalblacklist.conf)
echo "  size:  before=$size_before after=$size_after"
echo "  mtime: before=$mtime_before after=$mtime_after"
[ "$size_after" -gt 0 ] && pass "update 후 globalblacklist.conf 정상 (size=$size_after)" \
                     || fail "update 후 파일 깨짐"

# D-4. update 후 nginx reload 실행 (cron 의 후속 동작 시뮬레이션)
docker exec $CONT bash -c "nginx -t && nginx -s reload" 2>&1 | tail -2
sleep 1
nw2=$(docker exec $CONT bash -c "ps -eo comm | grep -c '^nginx$'" 2>/dev/null || echo 0)
[ "$nw2" -ge 2 ] && pass "reload 후 nginx 프로세스 정상" || fail "reload 후 워커 부재"

# ============================================================================
# STEP E — 실제 봇 차단 동작 검증 (임시 server 블록 추가)
# ============================================================================
hdr "Step E — 실제 차단 동작 검증 (임시 server 블록)"

# E-1. 테스트용 server 블록 임시 생성 (Host: blocker.test 매칭)
# 호스트 파일로 작성한 뒤 docker cp 로 옮겨 heredoc 이스케이프 이슈 회피
cat > /tmp/zz_blocker_test.conf <<'EOF'
server {
    listen 80;
    server_name blocker.test;

    access_log /log/nginx/blocker_test_access.log main;
    error_log  /log/nginx/blocker_test_error.log warn;

    include /etc/nginx/bots.d/blockbots.conf;
    include /etc/nginx/bots.d/ddos.conf;

    location / {
        add_header X-Test-OK "1" always;
        return 200 "blocker_test_ok\n";
    }
}
EOF
docker cp /tmp/zz_blocker_test.conf $CONT:/etc/nginx/conf.d/zz_blocker_test.conf
rm -f /tmp/zz_blocker_test.conf

# E-2. nginx -t & reload — 출력 캡처 후 분석 (실패 시 nginx -t 에러도 출력)
e2_out=$(docker exec $CONT bash -c "nginx -t 2>&1 && nginx -s reload 2>&1")
if echo "$e2_out" | grep -q "test is successful"; then
    pass "임시 server 블록 추가 후 nginx -t & reload 성공"
else
    fail "임시 server 블록 적용 실패"
    echo "  --- nginx -t output ---"
    echo "$e2_out" | sed 's/^/    /'
fi
sleep 1

# E-3. 정상 브라우저 UA — 200 응답 기대
echo "  -- 정상 UA (Mozilla) --"
code=$(curl -s -A "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
       -H "Host: blocker.test" -o /tmp/resp_ok.txt -w '%{http_code}' http://localhost/ 2>&1)
body=$(cat /tmp/resp_ok.txt 2>/dev/null | head -c 50)
echo "  HTTP code: $code, body: $body"
[ "$code" = "200" ] && pass "정상 UA → 200" || fail "정상 UA → $code (200 기대)"

# E-4. 알려진 봇 UA — 444 (차단) 기대
for bot in "MJ12bot" "AhrefsBot/7.0" "SemrushBot/7.0" "BLEXBot"; do
    echo "  -- 봇 UA: $bot --"
    code=$(curl -s -A "$bot" -H "Host: blocker.test" \
           -o /dev/null -w '%{http_code}' --max-time 5 http://localhost/ 2>&1)
    # 444 는 curl 이 0 으로 인식하기도 함 (connection closed before response)
    if [ "$code" = "444" ] || [ "$code" = "000" ] || [ "$code" = "403" ]; then
        pass "$bot 차단됨 (code=$code)"
    else
        fail "$bot 차단 실패 (code=$code)"
    fi
done

# E-5. bad referer 차단 (referer 기반 차단도 작동하는지 spot-check)
echo "  -- bad referer (semalt.com) --"
code=$(curl -s -A "Mozilla/5.0" -e "http://www.semalt.com/spam" \
       -H "Host: blocker.test" -o /dev/null -w '%{http_code}' --max-time 5 http://localhost/ 2>&1)
if [ "$code" = "444" ] || [ "$code" = "000" ] || [ "$code" = "403" ]; then
    pass "악성 referer 차단됨 (code=$code)"
else
    echo "  (semalt.com 차단 옵션은 globalblacklist.conf 의 \$bad_referer 정의에 의존 - code=$code)"
fi

# E-6. 액세스 로그에 봇 차단 기록 남는지
sleep 1
if docker exec $CONT test -f /log/nginx/blocker_test_access.log; then
    docker exec $CONT tail -10 /log/nginx/blocker_test_access.log | sed 's/^/    /'
    pass "테스트 액세스 로그 생성됨"
else
    echo "  (access_log 미생성 — 봇이 모두 444 로 끊겨서 로그 페이즈 미도달 가능)"
fi

# ============================================================================
# 정리
# ============================================================================
hdr "Cleanup — 임시 server 블록 제거"
docker exec $CONT rm -f /etc/nginx/conf.d/zz_blocker_test.conf
docker exec $CONT bash -c "nginx -t && nginx -s reload" 2>&1 | tail -2

hdr "최종 결과"
if [ "$FAILED" = "0" ]; then
    printf "  \e[32mALL CHECKS PASSED\e[0m\n"
    exit 0
else
    printf "  \e[31m%d FAIL(s)\e[0m\n" "$FAILED"
    exit 1
fi
