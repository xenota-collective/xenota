#!/usr/bin/env bash
set -euo pipefail

# Unit tests for tmux_reset_session branching on pane family.
#
# The live tmux calls inside tmux_reset_session are replaced by shell
# function overrides so this test runs without a tmux server.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"

# Mutable fakes controlled per test case.
_fake_family="shell"
_fake_idle_rc=0
_fake_ready_rc=0
_fake_claude_launch_rc=0

_launched_claude="false"
_sent_prompt_lines=()

tmux_pane_family() { printf '%s\n' "$_fake_family"; }
tmux_wait_for_idle_prompt() { return "$_fake_idle_rc"; }
tmux_wait_for_ready_prompt() { return "$_fake_ready_rc"; }
tmux_launch_claude_in_shell() { return "$_fake_claude_launch_rc"; }

tmux_send_prompt_line() { _sent_prompt_lines+=("$2"); }
tmux_send_literal_text() { :; }
tmux_send_raw_keys() { :; }

_reset() {
  _fake_family="shell"
  _fake_idle_rc=0
  _fake_ready_rc=0
  _fake_claude_launch_rc=0
  _launched_claude="false"
  _sent_prompt_lines=()
}

assert_rc() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "$label: expected rc=$expected, got rc=$actual" >&2
    exit 1
  fi
}

# Case 1: shell pane — expect rc=0 (launch claude succeeded).
_reset
_fake_family="shell"
_fake_claude_launch_rc=0
rc=0
tmux_reset_session "fake-target" || rc=$?
assert_rc "shell-launch-ok" 0 "$rc"

# Case 2: shell pane but claude launch failed — expect rc=2.
_reset
_fake_family="shell"
_fake_claude_launch_rc=1
rc=0
tmux_reset_session "fake-target" || rc=$?
assert_rc "shell-launch-fail" 2 "$rc"

# Case 3: claude pane, /clear succeeds — expect rc=0.
_reset
_fake_family="claude"
rc=0
tmux_reset_session "fake-target" || rc=$?
assert_rc "claude-clear-ok" 0 "$rc"
if [[ "${_sent_prompt_lines[0]:-}" != "/clear" ]]; then
  echo "claude-clear-ok: expected /clear prompt, got '${_sent_prompt_lines[0]:-}'" >&2
  exit 1
fi

# Case 4: claude pane, idle prompt never appears — expect rc=1.
_reset
_fake_family="claude"
_fake_idle_rc=1
rc=0
tmux_reset_session "fake-target" || rc=$?
assert_rc "claude-idle-timeout" 1 "$rc"

# Case 5: claude pane, /clear sent but ready prompt never returns — expect rc=1.
_reset
_fake_family="claude"
_fake_ready_rc=1
rc=0
tmux_reset_session "fake-target" || rc=$?
assert_rc "claude-ready-timeout" 1 "$rc"

# Case 6: unknown family (e.g. dead pane, zombie) — expect rc=3.
_reset
_fake_family="zombie"
rc=0
tmux_reset_session "fake-target" || rc=$?
assert_rc "unknown-family" 3 "$rc"

echo "test_tmux_reset_session: OK"
