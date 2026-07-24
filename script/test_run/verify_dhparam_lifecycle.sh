#!/usr/bin/env bash
# Standalone dhparam backup/restore behavior test.
# Spins up the nginx image with an empty host backup dir, verifies hook copies
# image→backup; then mutates the host backup, restarts, verifies container picks
# up the mutated host backup (restore-on-restart wins).
set -e

WORK=/tmp/dhparam-test
rm -rf "$WORK"
mkdir -p "$WORK/backup"

# 호스트 포트를 PID 기반으로 랜덤화하여 짧은 간격으로 반복 실행 시 TIME_WAIT 잔존 포트
# 충돌로 container 가 Created 상태에 머무는 사고 회피.
PORT_BASE=$(( 18080 + ($$ % 1000) * 3 ))
PORT_A=$PORT_BASE
PORT_B=$((PORT_BASE + 1))
PORT_C=$((PORT_BASE + 2))

cleanup() {
  for c in dhparam-test-1 dhparam-test-2 dhparam-test-3; do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "=== STEP A: empty backup dir, first run (hook should back up image→host) ==="
docker run -d --name dhparam-test-1 \
  -v "$WORK/backup":/etc/nginx/dhparam-backup \
  -p ${PORT_A}:80 \
  devspoon-nginx:latest >/dev/null
# nginx 공식 이미지의 entrypoint hook(20-dhparam.sh)이 실행되어 호스트 디렉토리에 파일이
# 떨어질 때까지 폴링. WSL bind mount + 공식 이미지의 다른 hook(envsubst-on-templates, cron 데몬 기동 등)
# 직렬화로 인해 6~10초가 소요되는 경우가 있어 sleep 고정값 대신 짧은 폴링 사용.
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  [ -s "$WORK/backup/dhparam.pem" ] && break
  sleep 1
done
# 호스트 백업 생성이 끝나도 nginx 공식 이미지의 다른 entrypoint hook(예: envsubst-on-templates,
# cron 데몬 기동 등)이 직렬화로 실행되는 동안 docker exec 가 아직 준비되지 않는 경우가 있다.
# OCI runtime exec failed 를 피하기 위해 docker exec true 폴링으로 컨테이너 준비를 확인한다.
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  docker exec dhparam-test-1 true >/dev/null 2>&1 && break
  sleep 1
done
echo "Host backup dir contents:"
ls -la "$WORK/backup/"
SHA_IMG=$(docker exec dhparam-test-1 sha256sum /etc/nginx/dhparam.pem | awk '{print $1}')
SHA_HOST=$(sha256sum "$WORK/backup/dhparam.pem" | awk '{print $1}')
echo "  container dhparam sha256: $SHA_IMG"
echo "  host backup  dhparam sha256: $SHA_HOST"
if [ "$SHA_IMG" = "$SHA_HOST" ]; then
  echo "  [PASS-A] image dhparam was backed up to host on first run"
else
  echo "  [FAIL-A] container and host backup differ"
  exit 1
fi
docker rm -f dhparam-test-1 >/dev/null

echo
echo "=== STEP B: stop+rerun with the same host backup (hook should restore host→container) ==="
docker run -d --name dhparam-test-2 \
  -v "$WORK/backup":/etc/nginx/dhparam-backup \
  -p ${PORT_B}:80 \
  devspoon-nginx:latest >/dev/null
# 컨테이너가 docker exec 를 받을 수 있는 상태가 될 때까지 폴링 (running + entrypoint hook 완료).
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  docker exec dhparam-test-2 true >/dev/null 2>&1 && break
  sleep 1
done
SHA_REBOOT=$(docker exec dhparam-test-2 sha256sum /etc/nginx/dhparam.pem | awk '{print $1}')
echo "  container dhparam sha256 after restart: $SHA_REBOOT"
if [ "$SHA_REBOOT" = "$SHA_HOST" ]; then
  echo "  [PASS-B] container has the host backup value after restart"
else
  echo "  [FAIL-B] container did not pick up host backup"
  exit 1
fi
docker rm -f dhparam-test-2 >/dev/null

echo
echo "=== STEP C: replace host backup with a different key, restart, host should win ==="
echo "  Writing sentinel dhparam (deterministic, no openssl call) ..."
# 의도적으로 openssl 호출을 피한다 — 실제 dhparam 생성/검증은 nginx 가 부팅 시 dhparam 으로
# 파싱하는 단계에서 실패해도 우리 hook 의 호스트 우선 정책만 검증하면 충분.
# 또한 일부 환경에서 openssl dhparam 1024-bit 가 비정상 종료(set -e 영향)로 스크립트 진행을
# 끊는 사고를 회피.
SENTINEL='-----BEGIN DH PARAMETERS-----
SENTINEL-DH-PARAM-FOR-HOOK-RESTORE-TEST-ONLY-NOT-A-VALID-PARAM
-----END DH PARAMETERS-----'
# 직전 컨테이너가 root 로 호스트에 쓴 파일은 일반 user 가 덮어쓸 수 없으므로
# 짧은 임시 컨테이너를 띄워 root 권한으로 호스트 백업 파일을 sentinel 값으로 교체한다.
docker run --rm -v "$WORK/backup":/backup alpine:3 \
  sh -c "printf '%s\n' \"$SENTINEL\" > /backup/dhparam.pem" >/dev/null
SHA_NEW=$(sha256sum "$WORK/backup/dhparam.pem" | awk '{print $1}')
echo "  new host dhparam sha256: $SHA_NEW (was $SHA_HOST)"
docker run -d --name dhparam-test-3 \
  -v "$WORK/backup":/etc/nginx/dhparam-backup \
  -p ${PORT_C}:80 \
  devspoon-nginx:latest >/dev/null
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  docker exec dhparam-test-3 true >/dev/null 2>&1 && break
  sleep 1
done
SHA_C=$(docker exec dhparam-test-3 sha256sum /etc/nginx/dhparam.pem | awk '{print $1}')
echo "  container dhparam sha256: $SHA_C"
if [ "$SHA_C" = "$SHA_NEW" ]; then
  echo "  [PASS-C] host backup wins on restore (image dhparam was overwritten)"
else
  echo "  [FAIL-C] container has image dhparam, host backup ignored"
  exit 1
fi

echo
echo "=== ALL PASS: dhparam backup/restore mechanism works as designed ==="
