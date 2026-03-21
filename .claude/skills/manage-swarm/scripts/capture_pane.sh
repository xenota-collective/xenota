#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <worker-name|tmux-target> [scrollback-lines]" >&2
  exit 2
fi

worker="$1"
scrollback="${2:-120}"

if [[ "$worker" == *:* ]]; then
  target="$worker"
else
  target="xc-crew-${worker}:0.0"
fi

exec /opt/homebrew/bin/tmux -L gt capture-pane -pt "$target" -S "-${scrollback}"
