#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <worker-name|tmux-target> <instruction>" >&2
  exit 2
fi

worker="$1"
shift
instruction="$*"

if [[ "$worker" == *:* ]]; then
  target="$worker"
else
  target="xc-crew-${worker}:0.0"
fi

tmux_cmd=(/opt/homebrew/bin/tmux -L gt)

submit_current_buffer() {
  "${tmux_cmd[@]}" send-keys -t "$target" Escape
  sleep 1
  "${tmux_cmd[@]}" send-keys -t "$target" Enter
}

"${tmux_cmd[@]}" send-keys -t "$target" Escape C-c
sleep 1
"${tmux_cmd[@]}" send-keys -t "$target" '/clear'
sleep 1
submit_current_buffer
sleep 3
"${tmux_cmd[@]}" send-keys -t "$target" "$instruction"
sleep 1
submit_current_buffer
