#!/usr/bin/env bash
# =============================================================================
# Generate per-domain HTTP nginx conf from sample_nginx.conf  (gunicorn stack)
#
# Usage (interactive):
#   ./nginx_conf.sh
#
# Usage (non-interactive):
#   ./nginx_conf.sh --webroot foo/bar --port 80 --domain example.com \
#                   --appname gunicorn-app --serviceport 8000 --filename example.com
#
# Output: ./conf.d/<filename>_gunicorn_ng.conf
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLE="${SCRIPT_DIR}/sample_nginx.conf"
OUT_DIR="${SCRIPT_DIR}/conf.d"
SUFFIX="_gunicorn_ng"

webroot=""
portnumber=""
domain=""
appname=""
serviceport=""
filename=""
force="0"

# ----- argv -------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --webroot)      webroot="$2"; shift 2;;
        --port)         portnumber="$2"; shift 2;;
        --domain)       domain="$2"; shift 2;;
        --appname)      appname="$2"; shift 2;;
        --serviceport)  serviceport="$2"; shift 2;;
        --filename)     filename="$2"; shift 2;;
        -f|--force)     force="1"; shift;;
        -h|--help)
            sed -n '2,15p' "$0"; exit 0;;
        *) echo "Unknown arg: $1" >&2; exit 2;;
    esac
done

prompt_required() {
    local var_name="$1" label="$2" current="${!var_name}"
    while [[ -z "$current" ]]; do
        read -r -p "$label > " current
    done
    printf -v "$var_name" '%s' "$current"
}

prompt_optional() {
    local var_name="$1" label="$2" current="${!var_name}"
    if [[ -z "$current" ]]; then
        read -r -p "$label (enter for none) > " current || true
    fi
    printf -v "$var_name" '%s' "$current"
}

prompt_required webroot     "Service web root under /www/ (e.g. shop/myapp)"
prompt_required portnumber  "Listen port (e.g. 80)"
prompt_required domain      "Domain (e.g. example.com)"
prompt_required appname     "Upstream service name (e.g. gunicorn-app)"
prompt_optional serviceport "Upstream port (e.g. 8000)"
prompt_required filename    "Output filename base (e.g. example.com)"

# ----- validation -------------------------------------------------------------
[[ -f "$SAMPLE" ]] || { echo "Sample not found: $SAMPLE" >&2; exit 1; }
mkdir -p "$OUT_DIR"

OUT_PATH="${OUT_DIR}/${filename}${SUFFIX}.conf"
if [[ -e "$OUT_PATH" && "$force" != "1" ]]; then
    echo "Output already exists: $OUT_PATH (use -f to overwrite)" >&2
    exit 1
fi

# ----- safe substitution (use a delimiter that cannot appear in inputs) -------
# We escape '/' in webroot to be sed-safe, then use a non-conflicting delimiter.
escape_sed() { printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'; }

E_WEBROOT=$(escape_sed "$webroot")
E_DOMAIN=$(escape_sed "$domain")
E_APPNAME=$(escape_sed "$appname")
E_FILENAME=$(escape_sed "$filename")
E_PORT=$(escape_sed "$portnumber")

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# Order matters: replace longer/more-specific tokens first to avoid partials
sed -e "s|webroot|${E_WEBROOT}|g" \
    -e "s|appname|${E_APPNAME}|g" \
    -e "s|filename|${E_FILENAME}|g" \
    -e "s|portnumber|${E_PORT}|g" \
    -e "s|www\\.domain|www.${E_DOMAIN}|g" \
    -e "s|domain|${E_DOMAIN}|g" \
    "$SAMPLE" > "$TMP"

# serviceport: empty -> drop ":serviceport" (port omitted form), else replace
if [[ -z "$serviceport" ]]; then
    sed -i 's|:serviceport||g' "$TMP"
else
    sed -i "s|serviceport|${serviceport}|g" "$TMP"
fi

mv "$TMP" "$OUT_PATH"
trap - EXIT

# ----- optional nginx -t inside container if available ------------------------
if command -v nginx >/dev/null 2>&1; then
    nginx -t 2>&1 || echo "WARNING: nginx -t failed. Inspect $OUT_PATH"
fi

echo "Wrote: $OUT_PATH"
