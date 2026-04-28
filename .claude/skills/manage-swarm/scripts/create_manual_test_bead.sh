#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <parent-epic> [priority]" >&2
  exit 2
fi

epic="$1"
priority="${2:-P1}"

cd /Users/jv/gt/xenota/mayor/rig
exec bd create --silent --parent "$epic" -t task -p "$priority" \
  --metadata '{"driver_preference": "strong", "risk_class": "tester"}' \
  "Execute manual testing plan for ${epic}"
