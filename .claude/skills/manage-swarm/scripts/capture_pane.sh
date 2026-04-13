#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <worker-name|tmux-target> [scrollback-lines]" >&2
  exit 2
fi

worker="$1"
scrollback="${2:-120}"
target="$(resolve_worker_target "$worker")"

exec "${tmux_cmd[@]}" capture-pane -pt "$target" -S "-${scrollback}"
