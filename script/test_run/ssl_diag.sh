#!/usr/bin/env bash
# 사용법: ssl_diag.sh [webserver_container]  (기본 nginx-gunicorn-webserver)
CT="${1:-nginx-gunicorn-webserver}"
echo "--- nginx error log tail ($CT) ---"
docker exec "$CT" tail -30 /log/nginx/error.log 2>&1
echo "--- direct s_client ---"
echo "Q" | openssl s_client -connect 127.0.0.1:443 -servername localhost 2>&1 | head -40
echo "--- curl verbose ---"
curl -vk https://127.0.0.1/ -H "Host: localhost" --max-time 10 2>&1 | head -40
