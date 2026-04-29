#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <parent-epic> [priority]" >&2
  exit 2
fi

epic="$1"
priority="${2:-P1}"

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel)"
exec bd create --silent --parent "$epic" -t task -p "$priority" "Execute manual testing plan for ${epic}"
