#!/bin/bash
set -euo pipefail
n=99999
(( 10#$n >= 1 && 10#$n <= 65535 )) || { echo "out of range" >&2; exit 2; }
echo OK
