#!/usr/bin/env bash
docker run --rm devspoon-test/gunicorn python -c 'import cgi; f=open(cgi.__file__).read(); print("LEN=", len(f)); print("LEGACY_IN_TEXT=", "legacy" in f.lower()); print("LEGACY_CGI_IN_TEXT=", "legacy-cgi" in f.lower())' 2>&1
echo "---"
docker run --rm devspoon-test/gunicorn ls /usr/local/lib/python3.14/site-packages/ 2>&1 | head -30
echo "---"
docker run --rm devspoon-test/gunicorn ls /usr/local/lib/python3.14/site-packages/legacy_cgi 2>&1
