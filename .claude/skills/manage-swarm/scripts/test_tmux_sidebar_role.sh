#!/usr/bin/env bash
set -euo pipefail

# Unit tests for the xc-23ub @agent_ui_role sidebar classifier in
# tmux_pane_is_sidebar.
#
# Verifies precedence:
#   1. @agent_ui_role=sidebar -> sidebar regardless of width / current
#      command (explicit operator/workmux marker wins).
#   2. @agent_ui_role=agent   -> NOT sidebar even when the pane is narrow
#      (last-resort width fallback is suppressed for legitimate narrow
#      agent panes; this is the council finding's actual fix).
#   3. No @agent_ui_role + current_command=workmux -> sidebar (existing
#      autodetect preserved).
#   4. No @agent_ui_role + width<40 + non-workmux command -> sidebar
#      (existing last-resort tiebreaker preserved).
#   5. No @agent_ui_role + width>=40 + non-workmux command -> NOT
#      sidebar.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Drive tmux interactions through a fake tmux that consults environment
# variables, so the test stays deterministic without a real tmux server.
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fake_tmux="$tmpdir/tmux"
cat <<'FAKE' >"$fake_tmux"
#!/usr/bin/env bash
case "$1" in
  display-message)
    shift
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        -p|-t)
          shift; [[ "$1" == -* ]] || shift
          ;;
        *)
          fmt="$1"; shift
          ;;
      esac
    done
    case "${fmt:-}" in
      '#{@agent_ui_role}') printf '%s\n' "${FAKE_AGENT_UI_ROLE:-}" ;;
      '#{pane_width}') printf '%s\n' "${FAKE_PANE_WIDTH:-120}" ;;
      *) printf '\n' ;;
    esac
    ;;
  *)
    exit 0
    ;;
esac
FAKE
chmod +x "$fake_tmux"
export TMUX_BIN="$fake_tmux"

source "$script_dir/tmux_target.sh"

tmux_pane_current_command() { printf '%s\n' "${FAKE_CURRENT_COMMAND:-zsh}"; }

assert_sidebar() {
  local label="$1"
  if ! tmux_pane_is_sidebar "fake-target"; then
    echo "$label: expected sidebar=true" >&2
    exit 1
  fi
}

assert_not_sidebar() {
  local label="$1"
  if tmux_pane_is_sidebar "fake-target"; then
    echo "$label: expected sidebar=false" >&2
    exit 1
  fi
}

# Case 1: explicit sidebar marker wins over wide pane and non-workmux cmd.
FAKE_AGENT_UI_ROLE="sidebar" FAKE_PANE_WIDTH=200 FAKE_CURRENT_COMMAND="zsh" \
  assert_sidebar "explicit-sidebar-wins"

# Case 2: explicit agent marker suppresses width fallback on narrow pane.
FAKE_AGENT_UI_ROLE="agent" FAKE_PANE_WIDTH=20 FAKE_CURRENT_COMMAND="zsh" \
  assert_not_sidebar "explicit-agent-suppresses-narrow"

# Case 3: no marker, current_command=workmux still classifies as sidebar.
FAKE_AGENT_UI_ROLE="" FAKE_PANE_WIDTH=120 FAKE_CURRENT_COMMAND="workmux" \
  assert_sidebar "workmux-autodetect"

# Case 4: no marker, narrow pane, non-workmux -> last-resort tiebreaker.
FAKE_AGENT_UI_ROLE="" FAKE_PANE_WIDTH=30 FAKE_CURRENT_COMMAND="zsh" \
  assert_sidebar "narrow-tiebreaker"

# Case 5: no marker, wide pane, non-workmux -> not a sidebar.
FAKE_AGENT_UI_ROLE="" FAKE_PANE_WIDTH=120 FAKE_CURRENT_COMMAND="zsh" \
  assert_not_sidebar "wide-shell-not-sidebar"

echo "test_tmux_sidebar_role: OK"
