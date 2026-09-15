#!/usr/bin/env bash
# =============================================================================
# 로그 비밀값 마스킹 필터 — CI 실패 알림 본문과 업로드 아티팩트(log/ci, log/test_run)에 공통 적용
#   mask_secrets              : stdin → stdout
#   mask_secrets_files DIR... : DIR 아래 모든 파일을 제자리 치환
# 대상 (대소문자 무시)
#   - 이름에 PASS·PWD·SECRET·TOKEN·KEY·AUTH 가 들어간 키의 값: KEY=값, KEY: 값, "KEY": "값", KEY='값'
#   - URL userinfo (redis://:pw@host), redis --requirepass 값, Bearer/Basic/Token 자격증명
# =============================================================================
MASK_SED=(
    -e "s/((Bearer|Basic|Token)[[:space:]]+)[^[:space:]\"',]+/\\1***/Ig"
    -e "s/(--requirepass[[:space:]]+)[^[:space:]\"',]+/\\1***/Ig"
    -e "s/((PASS|PWD|SECRET|TOKEN|KEY|AUTH)[A-Za-z0-9_]*\"?[[:space:]]*[=:][[:space:]]*)\"[^\"]*\"/\\1\"***\"/Ig"
    -e "s/((PASS|PWD|SECRET|TOKEN|KEY|AUTH)[A-Za-z0-9_]*'?[[:space:]]*[=:][[:space:]]*)'[^']*'/\\1'***'/Ig"
    -e "s/((PASS|PWD|SECRET|TOKEN|KEY|AUTH)[A-Za-z0-9_]*[[:space:]]*[=:][[:space:]]*)[^[:space:]\"',]+/\\1***/Ig"
    -e "s#(://[^:/@[:space:]]*:)[^@[:space:]]+@#\\1***@#g"
)
mask_secrets() { sed -E "${MASK_SED[@]}"; }
mask_secrets_files() { find "$@" -type f -exec sed -i -E "${MASK_SED[@]}" {} + 2>/dev/null; }
