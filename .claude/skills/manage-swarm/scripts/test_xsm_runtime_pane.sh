#!/usr/bin/env bash
set -euo pipefail

# Unit tests for resolve_xsm_runtime_pane and tag_xsm_runtime_pane (xc-6tdu2).
#
# Uses an isolated tmux server (-L socket) so the tests don't touch the
# operator's live xc session. The shell function overrides for
# ``tmux_session_exists`` are bypassed here because we run a real tmux
# server — the helpers only need access to ``list-panes`` and
# ``set-option`` which work the same on any server.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use a private tmux server so the tests can attach and detach without
# disturbing other panes. Each test invocation gets a fresh socket.
test_socket="xc6tdu2-$$-$RANDOM"
export TMUX_BIN="${TMUX_BIN:-/opt/homebrew/bin/tmux}"

cleanup() {
  "$TMUX_BIN" -L "$test_socket" kill-server 2>/dev/null || true
}
trap cleanup EXIT

# shellcheck source=./tmux_target.sh
source "$script_dir/tmux_target.sh"
# Override the global tmux command tuple to point at the private server.
tmux_cmd=("$TMUX_BIN" "-L" "$test_socket")

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $label"
    echo "  expected: '$expected'"
    echo "  actual:   '$actual'"
    exit 1
  fi
  echo "PASS: $label"
}

assert_nonempty() {
  local label="$1"
  local actual="$2"
  if [[ -z "$actual" ]]; then
    echo "FAIL: $label expected non-empty value"
    exit 1
  fi
  echo "PASS: $label"
}

# Bring up an isolated session named "xc" with three panes so we can
# tag one and verify the lookup ignores the others.
"$TMUX_BIN" -L "$test_socket" new-session -d -s xc -x 80 -y 24 "sleep 60"
"$TMUX_BIN" -L "$test_socket" split-window -t xc:0 -d "sleep 60"
"$TMUX_BIN" -L "$test_socket" split-window -t xc:0 -d "sleep 60"

# Capture all pane ids in the xc session for use in the tests.
pane_ids=()
while IFS= read -r line; do
  [[ -n "$line" ]] && pane_ids+=("$line")
done < <("$TMUX_BIN" -L "$test_socket" list-panes -t xc:0 -F '#{pane_id}')

if (( ${#pane_ids[@]} != 3 )); then
  echo "FAIL: expected 3 panes in xc session, got ${#pane_ids[@]}"
  exit 1
fi
echo "PASS: 3 panes ready in xc session"

# Case 1: no pane tagged → resolve returns empty (no error).
result="$(resolve_xsm_runtime_pane xc 2>/dev/null || true)"
assert_eq "no-tag-returns-empty" "" "$result"

# Case 2: tag the second pane → resolve returns its pane_id.
target_pane="${pane_ids[1]}"
tag_xsm_runtime_pane "$target_pane"
result="$(resolve_xsm_runtime_pane xc)"
assert_eq "single-tag-returns-pane-id" "$target_pane" "$result"

# Case 3: tag is per-pane and ignores other untagged panes in the
# same session. We just verified that — confirm the other ids are
# NOT in the result.
for pid in "${pane_ids[0]}" "${pane_ids[2]}"; do
  if [[ "$result" == *"$pid"* ]]; then
    echo "FAIL: untagged pane $pid leaked into resolve output"
    exit 1
  fi
done
echo "PASS: untagged panes excluded from resolve output"

# Case 4: tagging a second pane → resolve returns BOTH so the
# launcher can detect ambiguity and refuse to start.
second_target="${pane_ids[2]}"
tag_xsm_runtime_pane "$second_target"
result="$(resolve_xsm_runtime_pane xc)"
result_count="$(echo "$result" | wc -l | tr -d ' ')"
assert_eq "double-tag-returns-two-ids" "2" "$result_count"
if [[ "$result" != *"$target_pane"* || "$result" != *"$second_target"* ]]; then
  echo "FAIL: ambiguous resolve missing one of the tagged ids"
  exit 1
fi
echo "PASS: ambiguous resolve includes both tagged ids"

# Case 5: clearing the tag removes the pane from resolution.
"$TMUX_BIN" -L "$test_socket" set-option -p -t "$second_target" -u "@xsm_role"
result="$(resolve_xsm_runtime_pane xc)"
assert_eq "after-untag-returns-original" "$target_pane" "$result"

# Case 6: missing session → resolve returns empty without error.
result="$(resolve_xsm_runtime_pane no-such-session 2>/dev/null || true)"
assert_eq "missing-session-returns-empty" "" "$result"

echo
echo "All resolve_xsm_runtime_pane / tag_xsm_runtime_pane tests passed."
