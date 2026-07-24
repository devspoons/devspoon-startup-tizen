#!/usr/bin/env bash
# Section 2: Dockerfile build
set +e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG="$ROOT/log/test_run"
mkdir -p "$LOG"

# $1=tag suffix, $2=context dir under docker/, $3=optional Dockerfile name (default: Dockerfile)
build_one() {
    local name="$1" dir="$2" dockerfile="${3:-Dockerfile}"
    local start end elapsed
    echo "===== BUILD: devspoon-test/$name ====="
    start=$(date +%s)
    docker build -f "$ROOT/docker/$dir/$dockerfile" -t "devspoon-test/$name" "$ROOT/docker/$dir/" > "$LOG/build_${name}.log" 2>&1
    local ec=$?
    end=$(date +%s)
    elapsed=$((end - start))
    if [ $ec -eq 0 ]; then
        echo "  PASS  ($elapsed s)"
        tail -3 "$LOG/build_${name}.log"
    else
        echo "  FAIL  exit=$ec  ($elapsed s)"
        echo "--- last 40 lines of log ---"
        tail -40 "$LOG/build_${name}.log"
    fi
    echo "$name $ec $elapsed" >> "$LOG/build_summary.txt"
}

: > "$LOG/build_summary.txt"
build_one nginx        nginx
build_one gunicorn     gunicorn
build_one uwsgi        uwsgi
# php-fpm: startup-web 은 단일 php-8.4 Dockerfile 만 사용(기본 Dockerfile).
build_one php-fpm      php-fpm

echo ""
echo "===== build summary ====="
cat "$LOG/build_summary.txt"
echo ""
docker images | grep -E "devspoon-test/" || echo "no devspoon-test images"

# build_summary.txt 의 각 행은 "<name> <exit_code> <elapsed>". exit_code 가 0 이 아닌 빌드 수를 센다.
fails=$(awk '$2!=0{c++} END{print c+0}' "$LOG/build_summary.txt")
echo "build failures=$fails"
# 빌드가 하나라도 실패하면 non-zero 로 종료 → CI / 상위 스크립트가 $? 로 판정 가능.
[ "$fails" -eq 0 ]
exit $?
