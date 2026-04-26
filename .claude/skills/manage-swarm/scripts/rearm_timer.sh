#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <seconds> [state-file]" >&2
  exit 2
fi

seconds="$1"
state_file="${2:-/Users/jv/gt/xenota/crew/earthshot/swarm-state.yaml}"

if ! [[ "$seconds" =~ ^[0-9]+$ ]]; then
  echo "seconds must be an integer" >&2
  exit 2
fi

if [[ ! -f "$state_file" ]]; then
  echo "state file not found: $state_file" >&2
  exit 1
fi

wrangle_count="$(
  awk -F': *' '$1 == "wrangle_count" {print $2; exit}' "$state_file"
)"

if ! [[ "$wrangle_count" =~ ^[0-9]+$ ]]; then
  echo "could not parse wrangle_count from $state_file" >&2
  exit 1
fi

next_wrangle_count=$((wrangle_count + 1))

tmp_file="$(mktemp)"
awk -v next_count="$next_wrangle_count" '
  BEGIN { updated = 0 }
  /^wrangle_count:[[:space:]]*[0-9]+([[:space:]]*#.*)?$/ && updated == 0 {
    print "wrangle_count: " next_count
    updated = 1
    next
  }
  { print }
  END {
    if (updated == 0) {
      exit 1
    }
  }
' "$state_file" > "$tmp_file" || {
  rm -f "$tmp_file"
  echo "failed to update wrangle_count in $state_file" >&2
  exit 1
}
mv "$tmp_file" "$state_file"

timer_target="$(resolve_earthshot_timer_target)"
worker_target="$(resolve_earthshot_worker_target)"

if (( next_wrangle_count % 5 == 0 )); then
  arm_cmd="sleep ${seconds}; ${script_dir}/restart_wrangle.sh"
else
  printf -v quoted_worker '%q' "$worker_target"
  arm_cmd="sleep ${seconds}; ${script_dir}/send_worker_message.sh ${quoted_worker} 'wrangle the swarm'"
fi

"${tmux_cmd[@]}" clear-history -t "$timer_target"
"${tmux_cmd[@]}" respawn-pane -k -t "$timer_target" "$arm_cmd"
