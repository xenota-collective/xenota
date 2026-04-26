#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"

_fake_idle_rc=0
_fake_current_command="node"
_sent_text=()
_sent_keys=()
_prepared="false"

tmux_wait_for_idle_prompt() { return "$_fake_idle_rc"; }
tmux_wait_for_ready_prompt() { return 1; }
tmux_prepare_prompt_for_input() { _prepared="true"; }
tmux_send_literal_text() { _sent_text+=("$2"); }
tmux_send_raw_keys() { _sent_keys+=("$2"); }
tmux_pane_family() { printf 'shell\n'; }
tmux_pane_current_command() { printf '%s\n' "$_fake_current_command"; }
tmux_recent_pane_text() { printf 'starting claude\n'; }

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "$label: expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

rc=0
tmux_launch_claude_in_shell "fake-target" 1 || rc=$?
assert_eq "non-shell-command-is-launch-success" "0" "$rc"
assert_eq "shell-prepared-before-launch" "true" "$_prepared"
assert_eq "claude-command-sent" "claude" "${_sent_text[0]:-}"
assert_eq "enter-key-sent" "Enter" "${_sent_keys[0]:-}"

_fake_idle_rc=1
rc=0
tmux_launch_claude_in_shell "fake-target" 1 || rc=$?
assert_eq "idle-timeout-return-code" "2" "$rc"

echo "test_tmux_launch_claude: OK"
