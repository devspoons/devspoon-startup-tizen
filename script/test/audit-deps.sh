#!/usr/bin/env bash
# =============================================================================
# 파이썬 의존성 취약점 점검 — www/*/uv.lock 전수
#
# Usage:  bash script/test/audit-deps.sh
# Exit:   0 = PASS (취약점 없음 / 전부 허용목록) · 1 = FAIL (미허용 취약점 존재)
#
# 왜 이 스크립트인가
#   이 저장소는 PR 을 쓰지 않는다. 따라서 Dependabot 의 "security updates"
#   (= 자동 PR) 는 끌 수밖에 없고, 그만큼 "취약한 lock 이 master 에 머무는 것"을
#   막아 줄 게이트가 사라진다. 그 자리를 이 스크립트가 CI 단계로 대신한다.
#     - Dependabot alerts(경보)는 켜 둔 채 GitHub Security 탭에서 가시성만 유지
#     - 실제 차단은 push 마다 도는 CI 의 본 단계가 담당
#
#   컨테이너를 띄우지 않고 lock 파일만 읽으므로 수 초면 끝난다.
#
# 허용목록 (script/test/audit-allow.txt)
#   아직 상위 버전이 없는 등 당장 올릴 수 없는 권고는 ID 를 한 줄씩 적어 둔다.
#   허용목록으로 통과시킨 건은 PASS 로 처리하되 화면에 ALLOW 로 남겨
#   "조용히 묻히는 취약점"이 생기지 않게 한다.
#
# 주의 — `uv audit` 는 실험적(experimental) 기능이다.
#   출력 서식이 바뀔 수 있으므로 판정은 (1) 종료코드 와
#   (2) "Found N known vulnerabilities" 요약 문자열 두 가지에만 의존한다.
#   권고 ID 추출은 허용목록 대조 용도로만 쓰고, 추출에 실패하면
#   안전한 쪽(= FAIL)으로 떨어진다.
# =============================================================================
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1

ALLOW_FILE="$ROOT/script/test/audit-allow.txt"
FAILS=0
SCANNED=0

# ----- uv 가 없거나 audit 하위명령을 모르면 CI 를 빨갛게 만들지 않고 건너뛴다 -----
if ! command -v uv >/dev/null 2>&1; then
    echo "  [SKIP] uv 미설치 — 의존성 감사 건너뜀 (uv >= 0.11.3 필요)"
    exit 0
fi
if ! uv audit --help >/dev/null 2>&1; then
    echo "  [SKIP] 이 uv($(uv --version 2>/dev/null)) 에 audit 하위명령 없음 — 건너뜀 (>= 0.11.3 필요)"
    exit 0
fi

# ----- 허용목록 적재 (# 주석 · 빈 줄 무시, 첫 토큰만 ID 로 사용) -----
ALLOWED=""
if [ -f "$ALLOW_FILE" ]; then
    ALLOWED=$(sed -e 's/#.*//' -e 's/[[:space:]].*//' "$ALLOW_FILE" | grep -v '^$')
fi
is_allowed() { [ -n "$ALLOWED" ] && printf '%s\n' "$ALLOWED" | grep -qxF "$1"; }

echo "===== 의존성 취약점 감사 (uv audit · www/*/uv.lock) ====="
[ -n "$ALLOWED" ] && echo "  허용목록 $(printf '%s\n' "$ALLOWED" | wc -l) 건 적재: script/test/audit-allow.txt"

for lock in www/*/uv.lock; do
    [ -f "$lock" ] || continue
    proj="$(dirname "$lock")"
    SCANNED=$((SCANNED + 1))

    out=$(cd "$proj" && uv audit --frozen 2>&1); rc=$?

    # uv 자체 오류(lock 불일치·네트워크 등)는 "취약점 없음"과 구분해 실패시킨다.
    if [ "$rc" -ne 0 ] && ! printf '%s' "$out" | grep -q 'Found [0-9]* known vulnerabilit'; then
        echo "  [FAIL] ${proj#www/} — uv audit 실행 실패 (exit=$rc)"
        printf '%s\n' "$out" | sed 's/^/           /' | tail -15
        FAILS=$((FAILS + 1))
        continue
    fi

    summary=$(printf '%s' "$out" | grep -m1 'Found .* in [0-9]* packages')

    if [ "$rc" -eq 0 ]; then
        echo "  [PASS] ${proj#www/} — ${summary:-취약점 없음}"
        continue
    fi

    # 보고된 권고 ID 를 뽑아 허용목록과 대조한다.
    ids=$(printf '%s\n' "$out" | grep -oE '\b(GHSA-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}|PYSEC-[0-9]{4}-[0-9]+)\b' | sort -u)
    if [ -z "$ids" ]; then
        # 취약하다고는 하는데 ID 를 못 뽑았다 → 서식 변경 가능성. 안전한 쪽으로 실패.
        echo "  [FAIL] ${proj#www/} — ${summary:-취약점 보고} (권고 ID 추출 실패 — uv audit 출력 서식 변경 의심)"
        FAILS=$((FAILS + 1))
        continue
    fi

    blocked=""; allowed_hit=""
    for id in $ids; do
        if is_allowed "$id"; then allowed_hit="$allowed_hit $id"; else blocked="$blocked $id"; fi
    done

    if [ -n "$blocked" ]; then
        echo "  [FAIL] ${proj#www/} — ${summary:-취약점 보고}"
        for id in $blocked; do
            # 해당 권고의 패키지·수정버전을 함께 보여 준다 (조치 판단용).
            fixed=$(printf '%s\n' "$out" | grep -A3 -- "- $id:" | grep -m1 'Fixed in:' | sed 's/.*Fixed in: *//')
            echo "           미허용 $id${fixed:+  (수정판 $fixed)}"
        done
        echo "           조치: cd $proj && uv lock --upgrade-package <패키지>   또는 script/test/audit-allow.txt 에 ID 등록"
        FAILS=$((FAILS + 1))
    else
        echo "  [PASS] ${proj#www/} — 보고 $(printf '%s\n' "$ids" | wc -l) 건 전부 허용목록"
        for id in $allowed_hit; do echo "           ALLOW $id"; done
    fi
done

echo
if [ "$SCANNED" -eq 0 ]; then
    echo "  [FAIL] www/*/uv.lock 을 하나도 찾지 못했다 — 실행 위치나 저장소 구조 확인 필요"
    FAILS=$((FAILS + 1))
fi
echo "===== 감사 대상 ${SCANNED}개 · FAILS=$FAILS ====="
[ "$FAILS" -eq 0 ]
