#!/usr/bin/env bash
set -euo pipefail

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

tmux_cmd=(/opt/homebrew/bin/tmux -L gt)
timer_target="xc-crew-earthshot:0.2"
worker_target="xc-crew-earthshot:0.0"

"${tmux_cmd[@]}" send-keys -t "$timer_target" C-c
"${tmux_cmd[@]}" clear-history -t "$timer_target"
"${tmux_cmd[@]}" send-keys -t "$timer_target" 'clear' Enter
sleep 1

if (( next_wrangle_count % 5 == 0 )); then
  # Correct every-5th-pass re-arm with separate /clear and Enter
  arm_cmd="sleep ${seconds}; /opt/homebrew/bin/tmux -L gt send-keys -t ${worker_target} '/clear'; sleep 1; /opt/homebrew/bin/tmux -L gt send-keys -t ${worker_target} Enter; sleep 3; /opt/homebrew/bin/tmux -L gt send-keys -t ${worker_target} 'read the manage-swarm skill, then wrangle the swarm'; sleep 1; /opt/homebrew/bin/tmux -L gt send-keys -t ${worker_target} Enter"
else
  arm_cmd="sleep ${seconds}; /opt/homebrew/bin/tmux -L gt send-keys -t ${worker_target} 'wrangle the swarm'; sleep 1; /opt/homebrew/bin/tmux -L gt send-keys -t ${worker_target} Enter"
fi

"${tmux_cmd[@]}" send-keys -t "$timer_target" "$arm_cmd" C-m
