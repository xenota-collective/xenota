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

if ! "$script_dir/send_worker_message.sh" "$worker" "/clear"; then
  echo "clear_and_assign: centralized /clear delivery failed for $worker" >&2
  exit 1
fi

if ! tmux_wait_for_ready_prompt "$target" 30; then
  echo "clear_and_assign: /clear did not settle cleanly on $target" >&2
  tmux_recent_pane_text "$target" >&2
  exit 1
fi

"$script_dir/send_worker_message.sh" "$worker" "$instruction"
