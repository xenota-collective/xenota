#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"

_fake_panes=()
_created_pane=""

tmux_target_exists() {
  local target="$1"
  for pane in "${_fake_panes[@]}"; do
    [[ "$pane" == "$target" ]] && return 0
  done
  return 1
}

tmux_session_exists() {
  [[ "$1" == "xc-crew-earthshot" ]]
}

tmux_list_pane_targets() {
  printf '%s\n' "${_fake_panes[@]}"
}

tmux_pane_dead() {
  printf '0\n'
}

tmux_pane_current_command() {
  case "$1" in
    *:0.0) printf 'workmux\n' ;;
    *:0.1) printf 'zsh\n' ;;
    *:0.2) printf 'node\n' ;;
    *) printf 'zsh\n' ;;
  esac
}

tmux_pane_family() {
  case "$1" in
    *:0.0) printf 'shell\n' ;;
    *:0.1) printf 'shell\n' ;;
    *:0.2) printf 'claude\n' ;;
    *) printf 'shell\n' ;;
  esac
}

tmux_create_real_pane_in_window() {
  _created_pane="xc-crew-earthshot:0.1"
  printf '%s\n' "$_created_pane"
}

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "$label: expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

_fake_panes=("xc-crew-earthshot:0.0" "xc-crew-earthshot:0.1")
assert_eq "skip-workmux-sidebar" "xc-crew-earthshot:0.1" "$(resolve_named_lane_target "xc-crew-earthshot" "0.0")"

_fake_panes=("xc-crew-earthshot:0.0" "xc-crew-earthshot:0.1" "xc-crew-earthshot:0.2")
assert_eq "prefer-agent-pane" "xc-crew-earthshot:0.2" "$(resolve_named_lane_target "xc-crew-earthshot" "0.0")"

_fake_panes=("xc-crew-earthshot:0.0")
assert_eq "create-shell-when-only-sidebar" "xc-crew-earthshot:0.1" "$(resolve_named_lane_target "xc-crew-earthshot" "0.0")"

echo "test_tmux_target_selection: OK"
