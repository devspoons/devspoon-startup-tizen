#!/bin/bash
# ============================================================================
# uwsgi.ini 생성기 — sample_uwsgi.ini 의 placeholder(p_num / th_num / port_num)만 치환해 ./uwsgi.ini 로 출력한다.
#   - 프로젝트 폴더(chdir)·WSGI 모듈·로그 파일명은 ini 안의 $(PROJECT_DIR)·$(UWSGI_MODULE) 환경변수 치환을 따른다.
#     → compose .env 의 PROJECT_DIR·UWSGI_MODULE 로 지정한다 (생성기가 고정 경로를 박지 않는다).
#   - sample_uwsgi.ini 는 uwsgi.ini 와 placeholder 3줄만 다른 동기화 사본이다 (s6 6.20 단언).
# ============================================================================
set -euo pipefail
cd "$(dirname "$0")"

p_num=$(( $(nproc 2>/dev/null || echo 2) * 2 ))
th_num=$p_num
echo "process number is $p_num and thread number is $th_num"

while :
do
    echo -n "Enter the service port number >"
    read -r port_num || { echo "입력이 없습니다(EOF) — 중단" >&2; exit 2; }
    if [[ "$port_num" =~ ^[0-9]{1,5}$ ]] && (( 10#$port_num >= 1 && 10#$port_num <= 65535 )); then break; fi
    echo "  (포트 형식 오류 — 1-65535)"
done

sed -e "s/p_num/${p_num}/g" -e "s/th_num/${th_num}/g" -e "s/port_num/${port_num}/g" sample_uwsgi.ini > uwsgi.ini
echo "생성 완료: uwsgi.ini (프로젝트 폴더·모듈은 .env 의 PROJECT_DIR·UWSGI_MODULE)"
