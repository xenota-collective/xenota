#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"
target="$(resolve_earthshot_worker_target)"

send_literal() {
  "${tmux_cmd[@]}" send-keys -t "$target" -l "$1"
}

submit_current_buffer() {
  "${tmux_cmd[@]}" send-keys -t "$target" Enter
}

wait_for_text() {
  local needle="$1"
  local attempt recent
  for attempt in {1..10}; do
    recent="$(tmux_recent_pane_text "$target")"
    if grep -Fq "$needle" <<<"$recent"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

pane_title="$("${tmux_cmd[@]}" display-message -p -t "$target" '#{pane_title}')"
is_claude_pane=0
recent_before_clear="$(tmux_recent_pane_text "$target")"
if [[ "$pane_title" == *"Claude Code"* ]] || tmux_pane_looks_like_agent_ui "$recent_before_clear"; then
  is_claude_pane=1
fi

kickoff_instruction='read the manage-swarm skill, then wrangle the swarm'

"${tmux_cmd[@]}" send-keys -t "$target" Escape
if (( is_claude_pane == 0 )); then
  "${tmux_cmd[@]}" send-keys -t "$target" C-c
fi
sleep 1
send_literal '/clear'
sleep 1
submit_current_buffer

if ! tmux_wait_for_ready_prompt "$target"; then
  echo "restart_wrangle: /clear did not settle cleanly on $target" >&2
  tmux_recent_pane_text "$target" >&2
  exit 1
fi

send_literal "$kickoff_instruction"
sleep 1
submit_current_buffer

if ! wait_for_text "$kickoff_instruction"; then
  echo "restart_wrangle: kickoff instruction did not appear in $target after clear" >&2
  tmux_recent_pane_text "$target" >&2
  exit 1
fi
