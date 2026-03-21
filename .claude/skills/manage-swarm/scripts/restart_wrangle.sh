#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"
target="$(resolve_earthshot_worker_target)"

wait_for_text() {
  local needle="$1"
  tmux_wait_for_text "$target" "$needle" 10
}

kickoff_instruction='read the manage-swarm skill, then wrangle the swarm'

if ! tmux_reset_session "$target"; then
  echo "restart_wrangle: /clear did not settle cleanly on $target" >&2
  tmux_recent_pane_text "$target" >&2
  exit 1
fi

tmux_send_prompt_line "$target" "$kickoff_instruction"

if ! wait_for_text "$kickoff_instruction"; then
  echo "restart_wrangle: kickoff instruction did not appear in $target after clear" >&2
  tmux_recent_pane_text "$target" >&2
  exit 1
fi
