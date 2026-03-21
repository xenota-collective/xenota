#!/usr/bin/env bash
set -euo pipefail

tmux_cmd=(/opt/homebrew/bin/tmux -L gt)
target="xc-crew-earthshot:0.0"

"${tmux_cmd[@]}" send-keys -t "$target" '/clear'
sleep 1
"${tmux_cmd[@]}" send-keys -t "$target" Enter
sleep 3
"${tmux_cmd[@]}" send-keys -t "$target" 'read the manage-swarm skill, then wrangle the swarm'
sleep 1
"${tmux_cmd[@]}" send-keys -t "$target" Enter
