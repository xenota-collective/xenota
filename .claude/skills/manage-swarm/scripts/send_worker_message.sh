#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <worker-name|tmux-target> <message>" >&2
  exit 2
fi

worker="$1"
shift
message="$*"
target="$(resolve_worker_target "$worker")"

tmux_send_prompt_line "$target" "$message"
