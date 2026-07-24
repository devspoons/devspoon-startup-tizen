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

echo "===== 6 FAILS=$FAILS ====="
# 실패가 있으면 non-zero 로 종료 → CI / 상위 스크립트가 $? 로 판정 가능.
[ "$FAILS" -eq 0 ]
exit $?
