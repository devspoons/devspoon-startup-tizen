#!/bin/bash
# ============================================================================
# 도메인별 HTTP nginx conf 생성기 — sample_nginx_http.conf 의 placeholder 를 치환하여
#   ./conf.d/<NAME>_<STACK>_ng_http.conf 로 출력한다. (HTTPS 버전은 nginx_https_conf.sh)
# 동작 방식:
#   - 옵션을 주면 비대화형, 생략하면 대화형으로 묻는다.
#   - 같은 이름의 파일이 있어도 항상 덮어쓴다(백업이 필요하면 미리 복사할 것).
#   - nginx reload 는 자동으로 하지 않는다. 끝에 안내되는 명령을 수동 실행할 것.
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"          # 스크립트 위치(스택 디렉토리)로 이동 — 어디서 실행하든 동일하게 동작

STACK="php"              # 스택 이름 (생성 파일 접미사 / 컨테이너명 안내에 사용)
SAMPLE="sample_nginx_http.conf"
SUFFIX="_${STACK}_ng_http"

# 스택별 기본 서비스 포트 — usage() 예시와 prompt 기본값 안내에 사용 (php-fpm 은 9000, 그 외 Python 백엔드는 8000)
case "$STACK" in
    php) DEFAULT_SVCPORT=9000 ;;
    *)   DEFAULT_SVCPORT=8000 ;;
esac

usage() {
    cat <<EOF
======================================================================
  nginx HTTP 도메인 conf 생성기  —  ${STACK} 스택
======================================================================

이 스크립트는 ${SAMPLE} 의 placeholder 를 입력 값으로 치환해
./conf.d/<NAME>${SUFFIX}.conf 를 생성합니다. nginx 자체는 reload 하지 않습니다.

사용법:
  $(basename "$0") [옵션]

지원 옵션:
  -w WEBROOT     /www/ 아래 웹루트 경로 (예: django_sample, shop/myapp)
  -p PORT        서비스 listen 포트 (1-65535; 예: 80)
  -d DOMAIN      서비스 도메인 (예: example.com)
                 server_name <DOMAIN> www.<DOMAIN> 형태로 들어갑니다.
  -a APPNAME     백엔드 앱 컨테이너 이름 (예: ${STACK}-app)
                 백엔드 pass 대상 <APPNAME>:<SVCPORT> 의 호스트 부분.
  -s SVCPORT     백엔드 포트 (1-65535; ${STACK} 기본값 ${DEFAULT_SVCPORT})
                 빈 값으로 두면 ':SVCPORT' 가 제거되어 <APPNAME> (포트 없음) 형식.
  -n NAME        생성 파일/로그 식별자 (생략하면 DOMAIN 사용)
                 결과 파일명: ./conf.d/<NAME>${SUFFIX}.conf
  -h, --help     이 도움말 표시

비대화형 vs 대화형:
  - 위 옵션을 모두 주면 비대화형으로 즉시 파일 생성.
  - 일부만 주거나 전부 생략하면 누락된 항목만 대화형으로 묻습니다.
  - 검증 규칙: 포트 1-65535, 도메인/앱/이름은 [A-Za-z0-9._-]+, 웹루트는 / 도 허용.
  - 같은 이름의 conf 파일이 이미 있어도 항상 덮어씁니다 (백업은 호출 측 책임).

사용 예시:

  # (1) 샘플 사이트를 example.com 으로 띄우기 — 비대화형 (${STACK} 기본 포트 사용)
  $(basename "$0") -w django_sample -p 80 -d example.com \\
       -a ${STACK}-app -s ${DEFAULT_SVCPORT} -n example
  # → ./conf.d/example${SUFFIX}.conf

  # (2) 같은 스택, 다른 프로젝트 — 폴더만 다르고 옵션은 동일
  $(basename "$0") -w fastapi_sample -p 80 -d api.example.com \\
       -a ${STACK}-app -s ${DEFAULT_SVCPORT} -n api

  # (3) PHP 백엔드 (php-fpm 은 포트 9000)
  $(basename "$0") -w php_sample -p 80 -d shop.example.com \\
       -a php-app -s 9000 -n shop

  # (4) 일부 옵션만 주고 나머지는 대화형으로 입력받기
  $(basename "$0") -d api.example.com -a ${STACK}-app
  #   웹루트 / 포트 / 백엔드 포트 / NAME 을 대화형으로 묻습니다.

  # (5) 완전 대화형 모드 (옵션 없이 실행)
  $(basename "$0")

  # (6) 백엔드가 Unix socket 등으로 포트 없이 동작 — '-s' 를 빈 값으로
  $(basename "$0") -w mysite -p 80 -d example.com \\
       -a ${STACK}-app -s '' -n mysite
  # → 백엔드 pass 가 '${STACK}-app' (포트 없음) 형식

생성 후 반영 (스크립트가 자동으로 하지 않음):
  docker compose exec webserver nginx -t && \\
  docker compose exec webserver nginx -s reload
  # 또는 컨테이너명 직접 지정:
  docker exec nginx-${STACK}-webserver nginx -t && \\
  docker exec nginx-${STACK}-webserver nginx -s reload

관련 스크립트 및 다음 단계:
  ./nginx_https_conf.sh        — HTTPS(443) 도메인 conf 생성 (Let's Encrypt 발급 후)
  ../../../../script/letsencrypt.sh
                              — HTTPS 사용 시 초기 1회 발급 + 자동 갱신 cron 등록
                                (호출 순서: 본 스크립트로 HTTP conf 생성 → docker compose up
                                 → letsencrypt.sh → nginx_https_conf.sh → reload)
EOF
}

# --help 는 long option 으로 들어오므로 getopts 가 인식하지 못한다.
# 인자 목록을 사전 변환: --help → -h 로 바꿔 어디에 두든 도움말이 뜨도록 한다.
new_args=()
for arg in "$@"; do
    if [[ "$arg" == "--help" ]]; then new_args+=("-h"); else new_args+=("$arg"); fi
done
set -- "${new_args[@]}"

webroot="" ; portnumber="" ; domain="" ; appname="" ; serviceport="" ; name=""
svcport_set=0
while getopts ":w:p:d:a:s:n:h" opt; do
    case "$opt" in
        w) webroot="$OPTARG" ;; p) portnumber="$OPTARG" ;; d) domain="$OPTARG" ;;
        a) appname="$OPTARG" ;; s) serviceport="$OPTARG" ; svcport_set=1 ;; n) name="$OPTARG" ;;
        h) usage ; exit 0 ;;
        \?) echo "알 수 없는 옵션: -$OPTARG" >&2 ; usage ; exit 2 ;;
        :)  echo "옵션 -$OPTARG 에 값이 필요합니다" >&2 ; exit 2 ;;
    esac
done

# $1=대상변수명 $2=프롬프트 $3=검증 정규식(빈값이면 검증없음) $4="opt"면 빈 입력 허용
prompt_for() {
    local __var="$1" __msg="$2" __re="${3:-}" __opt="${4:-}" __val
    while :; do
        read -rp "$__msg" __val
        if [[ -z "$__val" && "$__opt" == "opt" ]]; then printf -v "$__var" '%s' "" ; return ; fi
        if [[ -z "$__val" ]]; then echo "  (값을 입력하세요)" ; continue ; fi
        if [[ -n "$__re" && ! "$__val" =~ $__re ]]; then echo "  (형식이 올바르지 않습니다)" ; continue ; fi
        printf -v "$__var" '%s' "$__val" ; return
    done
}

# placeholder 토큰(webroot/domain/appname/filename/serviceport)을 부분문자열 치환하므로,
# 토큰 자체나 sed delimiter(|) 와 충돌하는 문자가 입력에 들어오지 못하도록 정규식으로 제한한다.
[[ -n "$webroot"    ]] || prompt_for webroot    "웹루트 (/www/ 제외, 예: shop/myapp) > " '^[A-Za-z0-9._/-]+$'
[[ -n "$portnumber" ]] || prompt_for portnumber "서비스 listen 포트 (예: 80) > "          '^[0-9]{1,5}$'
[[ -n "$domain"     ]] || prompt_for domain     "서비스 도메인 (예: example.com) > "       '^[A-Za-z0-9.-]+$'
[[ -n "$appname"    ]] || prompt_for appname    "백엔드 앱 이름 (예: ${STACK}-app) > "     '^[A-Za-z0-9._-]+$'
if [[ "$svcport_set" -eq 0 && -z "$serviceport" ]]; then
    prompt_for serviceport "백엔드 포트 (예: 8000 / PHP-FPM 은 9000; 없으면 엔터) > " '^[0-9]{1,5}$' opt
fi
[[ -n "$name" ]] || name="$domain"

# 형식/범위 재검증 (옵션으로 받은 값 포함)
for v in "webroot:$webroot:^[A-Za-z0-9._/-]+\$" "domain:$domain:^[A-Za-z0-9.-]+\$" "appname:$appname:^[A-Za-z0-9._-]+\$" "name:$name:^[A-Za-z0-9._-]+\$"; do
    n="${v%%:*}" ; rest="${v#*:}" ; val="${rest%%:*}" ; re="${rest#*:}"
    [[ "$val" =~ $re ]] || { echo "$n 형식 오류: '$val'" >&2 ; exit 2 ; }
done
[[ "$portnumber" =~ ^[0-9]{1,5}$ ]] || { echo "PORT 형식 오류: '$portnumber'" >&2 ; exit 2 ; }
(( 10#$portnumber >= 1 && 10#$portnumber <= 65535 )) || { echo "PORT 범위 오류(1-65535): $portnumber" >&2 ; exit 2 ; }
if [[ -n "$serviceport" ]]; then
    [[ "$serviceport" =~ ^[0-9]{1,5}$ ]] || { echo "SVCPORT 형식 오류: '$serviceport'" >&2 ; exit 2 ; }
    (( 10#$serviceport >= 1 && 10#$serviceport <= 65535 )) || { echo "SVCPORT 범위 오류(1-65535): $serviceport" >&2 ; exit 2 ; }
fi
[[ -f "$SAMPLE" ]] || { echo "샘플 파일이 없습니다: $SAMPLE (스택 디렉토리에서 실행하세요)" >&2 ; exit 1 ; }

outfile="./conf.d/${name}${SUFFIX}.conf"
[[ -f "$outfile" ]] && echo "기존 파일을 덮어씁니다: $outfile"

# 단일 파이프 치환 — delimiter 를 | 로 두어 webroot 의 / 가 그대로 들어가도 안전(인용 처리됨, 임시파일 불필요)
sed_args=( -e "s|webroot|${webroot}|g" -e "s|portnumber|${portnumber}|g"
           -e "s|domain|${domain}|g"   -e "s|appname|${appname}|g" )
if [[ -z "$serviceport" ]]; then sed_args+=( -e "s|:serviceport||g" )
else                             sed_args+=( -e "s|serviceport|${serviceport}|g" ) ; fi
sed_args+=( -e "s|filename|${name}|g" )
sed "${sed_args[@]}" "$SAMPLE" > "$outfile"

echo "생성 완료: $outfile"
echo
echo "반영(수동으로 실행):"
echo "  docker compose exec webserver nginx -t && docker compose exec webserver nginx -s reload"
echo "  # 또는 컨테이너명 직접 지정:"
echo "  docker exec nginx-${STACK}-webserver nginx -t && docker exec nginx-${STACK}-webserver nginx -s reload"
