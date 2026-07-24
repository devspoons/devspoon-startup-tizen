#!/usr/bin/env bash
# =============================================================================
# Generate per-domain HTTP nginx conf from sample_nginx_proxy.conf  (proxy-only)
#
# Usage (interactive):
#   ./nginx_proxy_conf.sh
#
# Usage (non-interactive):
#   ./nginx_proxy_conf.sh --port 80 --domain example.com \
#                         --proxyurl backend --proxyport 8000 \
#                         --certbot-root /www/certbot --filename example.com
#
# Output: ./conf.d/<filename>_proxy_ng.conf
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLE="${SCRIPT_DIR}/sample_nginx_proxy.conf"
OUT_DIR="${SCRIPT_DIR}/conf.d"
SUFFIX="_proxy_ng"

portnumber=""
domain=""
proxyurl=""
proxyport=""
crontab_folder=""
filename=""
force="0"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port)         portnumber="$2"; shift 2;;
        --domain)       domain="$2"; shift 2;;
        --proxyurl)     proxyurl="$2"; shift 2;;
        --proxyport)    proxyport="$2"; shift 2;;
        --certbot-root) crontab_folder="$2"; shift 2;;
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

prompt_required portnumber      "Listen port (e.g. 80)"
prompt_required domain          "Domain (e.g. example.com)"
prompt_required proxyurl        "Upstream host (e.g. backend)"
prompt_optional proxyport       "Upstream port (e.g. 8000)"
prompt_required crontab_folder  "Certbot webroot for ACME challenge (e.g. /www/certbot)"
prompt_required filename        "Output filename base (e.g. example.com)"

[[ -f "$SAMPLE" ]] || { echo "Sample not found: $SAMPLE" >&2; exit 1; }
mkdir -p "$OUT_DIR"

OUT_PATH="${OUT_DIR}/${filename}${SUFFIX}.conf"
if [[ -e "$OUT_PATH" && "$force" != "1" ]]; then
    echo "Output already exists: $OUT_PATH (use -f to overwrite)" >&2
    exit 1
fi

escape_sed() { printf '%s' "$1" | sed -e 's/[\/&|]/\\&/g'; }
E_DOMAIN=$(escape_sed "$domain")
E_PROXYURL=$(escape_sed "$proxyurl")
E_FILENAME=$(escape_sed "$filename")
E_PORT=$(escape_sed "$portnumber")
E_CB=$(escape_sed "$crontab_folder")

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

sed -e "s|crontab_folder|${E_CB}|g" \
    -e "s|proxyurl|${E_PROXYURL}|g" \
    -e "s|filename|${E_FILENAME}|g" \
    -e "s|portnumber|${E_PORT}|g" \
    -e "s|www\\.domain|www.${E_DOMAIN}|g" \
    -e "s|domain|${E_DOMAIN}|g" \
    "$SAMPLE" > "$TMP"

if [[ -z "$proxyport" ]]; then
    sed -i 's|:proxyport||g' "$TMP"
else
    sed -i "s|proxyport|${proxyport}|g" "$TMP"
fi

mv "$TMP" "$OUT_PATH"
trap - EXIT

if command -v nginx >/dev/null 2>&1; then
    nginx -t 2>&1 || echo "WARNING: nginx -t failed. Inspect $OUT_PATH"
fi

echo "Wrote: $OUT_PATH"
