#!/usr/bin/env bash
# Step C in isolation - test that the host backup wins over the image dhparam.
set -e

WORK=/tmp/dhparam-stepc
rm -rf "$WORK"
mkdir -p "$WORK/backup"

cleanup() {
  docker rm -f dhparam-c-test >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "=== STEP C: host backup wins over image dhparam ==="
echo "Generating a fresh dhparam (1024-bit for speed)..."
openssl dhparam -out "$WORK/backup/dhparam.pem" 1024 2>/dev/null
NEW_HOST=$(sha256sum "$WORK/backup/dhparam.pem" | awk '{print $1}')
IMG_SHA=$(docker run --rm devspoon-nginx:latest sha256sum /etc/nginx/dhparam.pem | awk '{print $1}')

echo "  image dhparam  sha256: $IMG_SHA"
echo "  host  backup   sha256: $NEW_HOST"
if [ "$IMG_SHA" = "$NEW_HOST" ]; then
  echo "  [WARN] image and host backup happen to be identical (very unlikely) — test inconclusive"
  exit 1
fi

docker run -d --name dhparam-c-test \
  -v "$WORK/backup":/etc/nginx/dhparam-backup \
  devspoon-nginx:latest >/dev/null
sleep 3

CONT_SHA=$(docker exec dhparam-c-test sha256sum /etc/nginx/dhparam.pem | awk '{print $1}')
echo "  container       sha256 after start: $CONT_SHA"

if [ "$CONT_SHA" = "$NEW_HOST" ]; then
  echo "  [PASS-C] host backup wins (image dhparam was overridden by host backup)"
else
  echo "  [FAIL-C] container has image dhparam, host backup was ignored"
  exit 1
fi
