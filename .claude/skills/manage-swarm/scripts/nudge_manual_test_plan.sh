#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <worker-name> <epic>" >&2
  exit 2
fi

worker="$1"
epic="$2"

exec gt nudge "xenota/crew/${worker}" --mode immediate --message "Write a detailed manual testing plan as comments on ${epic} with setup, commands, pass/fail, and deferred integration gaps."
