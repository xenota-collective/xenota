#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <worker-name|tmux-target> <instruction>" >&2
  exit 2
fi

worker="$1"
shift
instruction="$*"

target="$(resolve_worker_target "$worker")"

send_literal() {
  "${tmux_cmd[@]}" send-keys -t "$target" -l "$1"
}

submit_current_buffer() {
  "${tmux_cmd[@]}" send-keys -t "$target" Enter
}

pane_title="$("${tmux_cmd[@]}" display-message -p -t "$target" '#{pane_title}')"
is_claude_pane=0
recent_before_clear="$(tmux_recent_pane_text "$target")"
if [[ "$pane_title" == *"Claude Code"* ]] || tmux_pane_looks_like_agent_ui "$recent_before_clear"; then
  is_claude_pane=1
fi

"${tmux_cmd[@]}" send-keys -t "$target" Escape
if (( is_claude_pane == 0 )); then
  "${tmux_cmd[@]}" send-keys -t "$target" C-c
fi
sleep 1
send_literal '/clear'
sleep 1
submit_current_buffer

if ! tmux_wait_for_ready_prompt "$target"; then
  echo "clear_and_assign: /clear did not settle cleanly on $target" >&2
  tmux_recent_pane_text "$target" >&2
  exit 1
fi

send_literal "$instruction"
sleep 1
submit_current_buffer
