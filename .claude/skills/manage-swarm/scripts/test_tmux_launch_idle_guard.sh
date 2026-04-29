#!/usr/bin/env bash
set -euo pipefail

# Unit tests for the xc-uhxy idle guard inside tmux_launch_claude_in_shell.
#
# Verifies:
#   1. When the pane is already idle on the short pre-probe, no C-c/C-u
#      reset is sent (avoids killing operator processes in misrouted panes).
#   2. When the short pre-probe times out, the C-c/C-u reset is still
#      delivered before the main idle wait + claude launch.
#   3. When the main idle wait fails, return code stays 2 (unchanged
#      contract for downstream callers like tmux_reset_session).
#
# tmux helpers are replaced with shell-function fakes so the test runs
# without a tmux server.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"

# Mutable fakes.
_idle_call_count=0
_idle_rc_sequence=()
_pane_family_after_launch="claude"
_sent_keys=()
_sent_text=()

tmux_wait_for_idle_prompt() {
  _idle_call_count=$((_idle_call_count + 1))
  local idx=$((_idle_call_count - 1))
  local rc="${_idle_rc_sequence[idx]:-0}"
  return "$rc"
}

tmux_wait_for_ready_prompt() { return 0; }

tmux_pane_family() { printf '%s\n' "$_pane_family_after_launch"; }

tmux_send_raw_keys() { _sent_keys+=("$2"); }
tmux_send_literal_text() { _sent_text+=("$2"); }

# Don't actually sleep in tests.
sleep() { :; }

_reset() {
  _idle_call_count=0
  _idle_rc_sequence=()
  _pane_family_after_launch="claude"
  _sent_keys=()
  _sent_text=()
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

assert_no_keys() {
  local label="$1"
  local needle="$2"
  for key in "${_sent_keys[@]+"${_sent_keys[@]}"}"; do
    if [[ "$key" == "$needle" ]]; then
      echo "$label: did not expect key '$needle' to be sent" >&2
      printf '  sent_keys: %s\n' "${_sent_keys[*]-}" >&2
      exit 1
    fi
  done
}

assert_has_keys() {
  local label="$1"
  local needle="$2"
  for key in "${_sent_keys[@]+"${_sent_keys[@]}"}"; do
    if [[ "$key" == "$needle" ]]; then
      return 0
    fi
  done
  echo "$label: expected key '$needle' to be sent" >&2
  printf '  sent_keys: %s\n' "${_sent_keys[*]-}" >&2
  exit 1
}

# Case 1: idle pane on first probe -> skip C-c/C-u, launch claude.
_reset
_idle_rc_sequence=(0 0)  # short pre-probe idle, main wait idle
rc=0
tmux_launch_claude_in_shell "fake-target" 1 || rc=$?
assert_eq "idle-skips-reset rc" 0 "$rc"
assert_no_keys "idle-skips-reset" "C-c"
assert_no_keys "idle-skips-reset" "C-u"
assert_has_keys "idle-skips-reset" "Enter"

# Case 2: not idle on first probe -> send C-c/C-u, then launch claude.
_reset
_idle_rc_sequence=(1 0)  # short pre-probe times out, main wait idle
rc=0
tmux_launch_claude_in_shell "fake-target" 1 || rc=$?
assert_eq "busy-sends-reset rc" 0 "$rc"
assert_has_keys "busy-sends-reset" "C-c"
assert_has_keys "busy-sends-reset" "C-u"

# Case 3: pre-probe idle but main wait fails -> rc=2 unchanged.
_reset
_idle_rc_sequence=(0 1)  # short pre-probe idle, main wait fails
rc=0
tmux_launch_claude_in_shell "fake-target" 1 || rc=$?
assert_eq "main-wait-fail rc" 2 "$rc"
assert_no_keys "main-wait-fail" "C-c"

# Case 4: pre-probe times out and main wait fails -> still rc=2.
_reset
_idle_rc_sequence=(1 1)  # short pre-probe and main wait both fail
rc=0
tmux_launch_claude_in_shell "fake-target" 1 || rc=$?
assert_eq "double-fail rc" 2 "$rc"
assert_has_keys "double-fail" "C-c"
assert_has_keys "double-fail" "C-u"

echo "test_tmux_launch_idle_guard: OK"
