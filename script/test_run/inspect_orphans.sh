#!/usr/bin/env bash
# 컨테이너의 compose project/config 라벨과 상태를 확인 (orphan 추적용).
# 사용법: inspect_orphans.sh [container ...]
#   인자 없으면 devspoon 의 주요 스택 컨테이너를 기본 검사한다.
containers=("$@")
if [ ${#containers[@]} -eq 0 ]; then
    containers=(nginx-daphne-webserver daphne-app \
                nginx-gunicorn-webserver gunicorn-app \
                nginx-uwsgi-webserver uwsgi-app \
                nginx-uvicorn-webserver uvicorn-app \
                nginx-php-webserver \
                redis_db celery-app)
fi
for c in "${containers[@]}"; do
    echo "=== $c ==="
    docker inspect "$c" --format 'project={{ index .Config.Labels "com.docker.compose.project" }} cfg={{ index .Config.Labels "com.docker.compose.project.config_files" }} status={{ .State.Status }}' 2>&1
done
