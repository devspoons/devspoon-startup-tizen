#!/bin/bash
# ============================================================================
# 도메인별 php-fpm 풀 생성기 — sample_php.conf 의 placeholder (domain / portnumber)
# 를 치환하여 ./pool.d/<DOMAIN>_php.conf 로 출력한다.
#
# 동작:
#   - domain 입력 → [domain] 섹션 헤더와 출력 파일명에 사용
#   - portnumber 입력 → listen = [::]:<portnumber> (php-fpm 기본 9000)
#   - 같은 이름의 파일이 있어도 항상 덮어쓴다 (백업 필요 시 호출 측 책임)
#   - php-fpm reload 는 자동으로 하지 않음 — docker compose 컨테이너 restart 로 반영
#
# 1차 audit 이후 추가된 안전장치:
#   - sed delimiter 를 | 로 두어 도메인의 . 가 안전하게 들어가게 함
#   - 입력값 정규식 검증 (도메인 [A-Za-z0-9.-]+, 포트 1-65535)
#   - sample 파일에 placeholder (domain / portnumber) 만 등장하도록 sample 정비
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

SAMPLE="sample_php.conf"
[[ -f "$SAMPLE" ]] || { echo "샘플 파일이 없습니다: $SAMPLE (스크립트와 같은 디렉토리에서 실행하세요)" >&2 ; exit 1 ; }

while :
do
    echo -n "Enter the service domain >"
    read domain
    echo  "Entered service domain: $domain"
    if [[ -z "$domain" ]]; then
        echo "  (도메인을 입력하세요)"
        continue
    fi
    if [[ ! "$domain" =~ ^[A-Za-z0-9.-]+$ ]]; then
        echo "  (도메인 형식 오류 — [A-Za-z0-9.-]+ 만 허용)"
        continue
    fi
    break
done

while :
do
    echo -n "Enter the service portnumber >"
    read portnumber
    echo  "Entered service portnumber: $portnumber"
    if [[ -z "$portnumber" ]]; then
        echo "  (포트를 입력하세요)"
        continue
    fi
    if [[ ! "$portnumber" =~ ^[0-9]{1,5}$ ]]; then
        echo "  (포트 형식 오류 — 1-5 자리 숫자)"
        continue
    fi
    if (( 10#$portnumber < 1 || 10#$portnumber > 65535 )); then
        echo "  (포트 범위 오류 — 1-65535)"
        continue
    fi
    break
done

mkdir -p ./pool.d
outfile="./pool.d/${domain}_php.conf"
[[ -f "$outfile" ]] && echo "기존 파일을 덮어씁니다: $outfile"

# delimiter | 로 안전 치환. sample 의 placeholder 는 domain / portnumber 두 개뿐.
sed -e "s|domain|${domain}|g" -e "s|portnumber|${portnumber}|g" "$SAMPLE" > "$outfile"

echo "생성 완료: $outfile"
echo
echo "반영(수동):"
echo "  docker compose restart php-app"
