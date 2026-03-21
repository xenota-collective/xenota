#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <worker-name> [scrollback-lines]" >&2
  exit 2
fi

worker="$1"
scrollback="${2:-120}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

printf 'PANE\n'
"$script_dir/capture_pane.sh" "$worker" "$scrollback"
printf '\nCREW_STATUS\n'
"$script_dir/crew_status.sh" "$worker"
