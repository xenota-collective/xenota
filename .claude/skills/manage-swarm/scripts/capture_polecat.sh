#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <polecat-name|tmux-target> [scrollback-lines]" >&2
  exit 2
fi

polecat="$1"
scrollback="${2:-120}"

if [[ "$polecat" == *:* ]]; then
  target="$polecat"
else
  target="xc-${polecat}:0.0"
fi

exec /opt/homebrew/bin/tmux -L gt capture-pane -pt "$target" -S "-${scrollback}"
