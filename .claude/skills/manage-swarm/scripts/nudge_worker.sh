#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <worker-name> <message>" >&2
  exit 2
fi

worker="$1"
shift

exec gt nudge "xenota/crew/${worker}" --mode immediate --message "$*"
