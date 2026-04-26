#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"
target="$(resolve_wrangle_worker_target)"

wait_for_text() {
  local needle="$1"
  tmux_wait_for_text "$target" "$needle" 10
}

kickoff_instruction='read the manage-swarm skill, then wrangle the swarm'

reset_rc=0
tmux_reset_session "$target" || reset_rc=$?
case "$reset_rc" in
  0)
    ;;
  1)
    echo "restart_wrangle: /clear did not settle cleanly on $target" >&2
    tmux_recent_pane_text "$target" >&2
    exit 1
    ;;
  2)
    echo "restart_wrangle: $target was at a shell prompt and claude could not be re-launched" >&2
    tmux_recent_pane_text "$target" >&2
    exit 1
    ;;
  3)
    echo "restart_wrangle: $target family=$(tmux_pane_family "$target") has no reset path; operator recovery required" >&2
    tmux_recent_pane_text "$target" >&2
    exit 1
    ;;
  *)
    echo "restart_wrangle: tmux_reset_session failed on $target with rc=$reset_rc" >&2
    tmux_recent_pane_text "$target" >&2
    exit 1
    ;;
esac

tmux_send_prompt_line "$target" "$kickoff_instruction"

if ! wait_for_text "$kickoff_instruction"; then
  echo "restart_wrangle: kickoff instruction did not appear in $target after reset" >&2
  tmux_recent_pane_text "$target" >&2
  exit 1
fi
