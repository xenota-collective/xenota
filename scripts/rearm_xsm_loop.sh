#!/usr/bin/env bash
set -euo pipefail

tmux_cmd=(/opt/homebrew/bin/tmux -L gt)
timer_target="${1:-xc-crew-horizon:0.2}"
worker_target="${2:-xc-crew-horizon:0.0}"
seconds="${3:-180}"

message="inspect xsm live state, restart wrangle if needed, and fix the next control-plane blocker"

if ! [[ "$seconds" =~ ^[0-9]+$ ]]; then
  echo "seconds must be an integer" >&2
  exit 2
fi

"${tmux_cmd[@]}" send-keys -t "$timer_target" C-c
"${tmux_cmd[@]}" clear-history -t "$timer_target"
"${tmux_cmd[@]}" send-keys -t "$timer_target" "clear" Enter
sleep 1

loop_cmd=$(
  cat <<EOF
while true; do
  sleep ${seconds}
  ${tmux_cmd[*]} send-keys -t ${worker_target} C-u
  ${tmux_cmd[*]} send-keys -t ${worker_target} -l '${message}'
  sleep 1
  ${tmux_cmd[*]} send-keys -t ${worker_target} Enter
done
EOF
)

"${tmux_cmd[@]}" send-keys -t "$timer_target" -l "$loop_cmd"
"${tmux_cmd[@]}" send-keys -t "$timer_target" Enter
