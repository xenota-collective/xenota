#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 <parent-epic> <agent: claude|codex> [priority]" >&2
  exit 2
fi

epic="$1"
agent="$2"
priority="${3:-P1}"

cd /Users/jv/gt/xenota/mayor/rig
exec bd create --silent --parent "$epic" -t task -p "$priority" \
  --metadata '{"driver_preference": "strong", "risk_class": "reviewer"}' \
  "Run full ${agent} polecat code review for ${epic}"
