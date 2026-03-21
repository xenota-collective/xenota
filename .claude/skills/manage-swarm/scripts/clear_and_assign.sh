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

if ! tmux_reset_session "$target"; then
  echo "clear_and_assign: /clear did not settle cleanly on $target" >&2
  tmux_recent_pane_text "$target" >&2
  exit 1
fi

tmux_send_prompt_line "$target" "$instruction"
