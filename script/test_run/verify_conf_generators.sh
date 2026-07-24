#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
echo "=== Testing all 4 stacks nginx conf generators ==="
for stack in gunicorn uvicorn uwsgi php; do
  cd "$ROOT/config/web-server/nginx/$stack"
  chmod +x nginx_http_conf.sh nginx_https_conf.sh
  case "$stack" in
    gunicorn) appname=gunicorn-app; svcport=8000; webroot=django_sample ;;
    uvicorn)  appname=uvicorn-app;  svcport=8000; webroot=django_sample ;;
    uwsgi)    appname=uwsgi-app;    svcport=8000; webroot=django_sample ;;
    php)      appname=php-app;      svcport=9000; webroot=php_sample ;;
  esac
  echo
  echo "--- [$stack] HTTP generator ---"
  ./nginx_http_conf.sh -w "$webroot" -p 80 -d "test.${stack}.local" -a "$appname" -s "$svcport" -n test 2>&1 | grep -E "생성 완료|Error" || true
  HTTP_FILE="conf.d/test_${stack}_ng_http.conf"
  if [ -f "$HTTP_FILE" ]; then
    echo "  PASS: $HTTP_FILE created ($(wc -c < "$HTTP_FILE") bytes)"
  else
    echo "  FAIL: $HTTP_FILE not created"
  fi

  echo "--- [$stack] HTTPS generator ---"
  ./nginx_https_conf.sh -w "$webroot" -p 80 -d "test.${stack}.local" -a "$appname" -s "$svcport" -n test 2>&1 | grep -E "생성 완료|Error" || true
  HTTPS_FILE="conf.d/test_${stack}_ng_https.conf"
  if [ -f "$HTTPS_FILE" ]; then
    echo "  PASS: $HTTPS_FILE created ($(wc -c < "$HTTPS_FILE") bytes)"
  else
    echo "  FAIL: $HTTPS_FILE not created"
    continue
  fi
  DH=$(grep -E "ssl_dhparam" "$HTTPS_FILE" | head -1 | sed -e 's/^[[:space:]]*//' )
  CERT=$(grep -E "ssl_certificate\s" "$HTTPS_FILE" | head -1 | sed -e 's/^[[:space:]]*//' )
  KEY=$(grep -E "ssl_certificate_key" "$HTTPS_FILE" | head -1 | sed -e 's/^[[:space:]]*//' )
  echo "    $DH"
  echo "    $CERT"
  echo "    $KEY"
done

echo
echo "=== Cleanup: removing test conf files ==="
for stack in gunicorn uvicorn uwsgi php; do
  rm -f "$ROOT/config/web-server/nginx/$stack"/conf.d/test_*.conf
done
echo "Done."
