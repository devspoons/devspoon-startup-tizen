#!/usr/bin/env bash
# Section 2-A: container internal inspections for each image
set +e

check_label() {
    echo ""
    echo "===== $1 ====="
    shift
    "$@"
    echo "  exit=$?"
}

inspect() {
    local img="$1"
    echo ""
    echo "###############  IMAGE: $img  ###############"
    check_label "2A.1 logrotate version" docker run --rm "$img" logrotate --version 2>&1 | head -3
    check_label "2A.2 cron command path" docker run --rm "$img" sh -c "command -v cron || command -v crond"
    check_label "2A.3 crontab -l" docker run --rm "$img" crontab -l 2>&1 | head -10
}

for img in devspoon-test/nginx devspoon-test/gunicorn devspoon-test/uwsgi devspoon-test/php-fpm; do
    if docker image inspect "$img" >/dev/null 2>&1; then
        inspect "$img"
    else
        echo "SKIP $img (not built yet)"
    fi
done

echo ""
echo "===== 2A.4 entrypoint-with-cron (gunicorn/uwsgi/php-fpm) ====="
# 과거 'with-cron.sh' + 'logrotate-all.sh' 파일명은 entrypoint-with-cron 으로 통합되었다.
# (docker/{gunicorn,uwsgi,php-fpm}/Dockerfile 의 COPY entrypoint-with-cron.sh /usr/local/bin/entrypoint-with-cron)
for img in devspoon-test/gunicorn devspoon-test/uwsgi devspoon-test/php-fpm; do
    if docker image inspect "$img" >/dev/null 2>&1; then
        echo "--- $img ---"
        docker run --rm --entrypoint /bin/sh "$img" -c "ls -l /usr/local/bin/entrypoint-with-cron" 2>&1
    else
        echo "SKIP $img"
    fi
done

echo ""
echo "===== 2A.5 nginx entrypoint hook 20-dhparam.sh ====="
# 과거 40-start-cron.sh 는 docker-entrypoint.sh 안에 sed 로 'cron' 라인 삽입 방식으로 대체되었고
# (docker/nginx/Dockerfile 섹션 5), 별도 hook 으로는 20-dhparam.sh (dhparam 백업/복원) 만 존재한다.
if docker image inspect devspoon-test/nginx >/dev/null 2>&1; then
    docker run --rm --entrypoint sh devspoon-test/nginx -c "ls -l /docker-entrypoint.d/20-dhparam.sh"
fi

echo ""
echo "===== 2A.6 nginx certbot ====="
if docker image inspect devspoon-test/nginx >/dev/null 2>&1; then
    docker run --rm --entrypoint certbot devspoon-test/nginx --version 2>&1 | head -3
fi

echo ""
echo "===== 2A.7 gunicorn uv version ====="
if docker image inspect devspoon-test/gunicorn >/dev/null 2>&1; then
    docker run --rm devspoon-test/gunicorn uv --version 2>&1
fi

echo ""
echo "===== 2A.8 gunicorn python --version ====="
if docker image inspect devspoon-test/gunicorn >/dev/null 2>&1; then
    docker run --rm devspoon-test/gunicorn python --version 2>&1
fi

echo ""
echo "===== 2A.9 gunicorn cgi legacy shim ====="
if docker image inspect devspoon-test/gunicorn >/dev/null 2>&1; then
    docker run --rm devspoon-test/gunicorn python -c "import cgi, sys; p=cgi.__file__; sys.exit(0 if 'site-packages' in p and 'legacy' in open(p).read(2048).lower() else 1)" 2>&1
    echo "  exit=$?"
fi

echo ""
echo "===== 2A.10 uwsgi python ====="
if docker image inspect devspoon-test/uwsgi >/dev/null 2>&1; then
    docker run --rm --entrypoint /bin/sh devspoon-test/uwsgi -c "python --version" 2>&1
fi
