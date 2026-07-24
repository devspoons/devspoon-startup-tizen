#!/usr/bin/env bash
docker run --rm devspoon-test/gunicorn python -c 'import cgi; print("FILE=", cgi.__file__)' 2>&1
echo "---"
docker run --rm devspoon-test/gunicorn python -c 'import cgi; f=open(cgi.__file__).read(2048); print(f[:800])' 2>&1
echo "---"
docker run --rm devspoon-test/gunicorn pip show legacy-cgi 2>&1 | head -10
