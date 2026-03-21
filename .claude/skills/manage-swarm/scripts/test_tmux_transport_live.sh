#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"

start_session() {
  local family="$1"
  local session="$2"
  local launch_cmd

  "${tmux_cmd[@]}" kill-session -t "$session" >/dev/null 2>&1 || true

  case "$family" in
    claude)
      launch_cmd='exec env -u CLAUDECODE NODE_OPTIONS="" /Users/jv/.local/bin/claude --bare --dangerously-skip-permissions'
      ;;
    gemini)
      launch_cmd='gemini --approval-mode yolo'
      ;;
    codex)
      launch_cmd='codex --dangerously-bypass-approvals-and-sandbox'
      ;;
    *)
      echo "unknown family: $family" >&2
      exit 1
      ;;
  esac

  "${tmux_cmd[@]}" new-session -d -s "$session" -n node "$launch_cmd"
}

assert_family() {
  local expected="$1"
  local target="$2"
  local actual

  actual="$(tmux_pane_family "$target")"
  if [[ "$actual" != "$expected" ]]; then
    echo "expected family $expected for $target, got $actual" >&2
    tmux_recent_pane_text "$target" >&2
    exit 1
  fi
}

assert_ready() {
  local target="$1"
  if ! tmux_wait_for_ready_prompt "$target" 30; then
    echo "target did not become ready: $target" >&2
    tmux_recent_pane_text "$target" >&2
    exit 1
  fi
}

assert_marker_visible() {
  local target="$1"
  local marker="$2"

  if ! tmux_wait_for_text "$target" "$marker" 10; then
    echo "marker not visible in $target: $marker" >&2
    tmux_recent_pane_text "$target" >&2
    exit 1
  fi
}

run_family_test() {
  local family="$1"
  local session="xc-transport-${family}"
  local target="${session}:0.0"
  local direct_marker="${family^^}_DIRECT_MARK_20260321"
  local post_clear_marker="${family^^}_POST_CLEAR_MARK_20260321"

  start_session "$family" "$session"
  assert_ready "$target"
  assert_family "$family" "$target"

  tmux_send_prompt_line "$target" "$direct_marker"
  assert_marker_visible "$target" "$direct_marker"

  tmux_reset_session "$target"
  assert_ready "$target"

  tmux_send_prompt_line "$target" "$post_clear_marker"
  assert_marker_visible "$target" "$post_clear_marker"
}

run_family_test claude
run_family_test gemini
run_family_test codex

echo "tmux live transport checks passed"
