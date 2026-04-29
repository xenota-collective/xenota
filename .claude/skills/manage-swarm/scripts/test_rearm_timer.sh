#!/usr/bin/env bash
set -euo pipefail

# Regression tests for rearm_timer target resolution. The tmux binary is a
# deterministic fake so these checks cannot create real tmux sessions.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fake_tmux="$tmpdir/tmux"
call_log="$tmpdir/calls.log"
sessions_file="$tmpdir/sessions"
targets_file="$tmpdir/targets"
commands_file="$tmpdir/commands"

cat >"$fake_tmux" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${FAKE_TMUX_CALL_LOG:?}"

has_line() {
  local file="$1"
  local needle="$2"
  [[ -f "$file" ]] && grep -Fxq "$needle" "$file"
}

target_command() {
  local target="$1"
  awk -v target="$target" '$1 == target { $1 = ""; sub(/^ /, ""); print; found = 1; exit } END { exit found ? 0 : 1 }' "${FAKE_TMUX_COMMANDS_FILE:?}" || true
}

case "${1:-}" in
  has-session)
    [[ "${2:-}" == "-t" ]] || exit 2
    has_line "${FAKE_TMUX_SESSIONS_FILE:?}" "${3:-}"
    ;;
  list-panes)
    target=""
    format=""
    shift
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        -t)
          target="$2"
          shift 2
          ;;
        -F)
          format="$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    if [[ "$target" == *:*.* ]]; then
      has_line "${FAKE_TMUX_TARGETS_FILE:?}" "$target"
      exit $?
    fi
    session="${target%%:*}"
    if ! has_line "${FAKE_TMUX_SESSIONS_FILE:?}" "$session"; then
      exit 1
    fi
    if [[ "$format" == "#S:#I.#P" ]]; then
      printf '%s:0.0\n' "$session"
    else
      printf '0.0\n'
    fi
    ;;
  display-message)
    target=""
    format=""
    shift
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        -p)
          shift
          ;;
        -t)
          target="$2"
          shift 2
          ;;
        *)
          format="$1"
          shift
          ;;
      esac
    done
    case "$format" in
      '#{pane_current_command}') target_command "$target" ;;
      '#{pane_start_command}') printf '%s\n' "$(target_command "$target")" ;;
      '#{pane_title}') printf '%s\n' "$(target_command "$target")" ;;
      '#{pane_width}') printf '120\n' ;;
      *) printf '\n' ;;
    esac
    ;;
  capture-pane)
    printf 'shell prompt\n'
    ;;
  clear-history|respawn-pane)
    exit 0
    ;;
  new-session|new-window|split-window)
    exit 99
    ;;
  *)
    exit 2
    ;;
esac
FAKE
chmod +x "$fake_tmux"

export TMUX_BIN="$fake_tmux"
export FAKE_TMUX_CALL_LOG="$call_log"
export FAKE_TMUX_SESSIONS_FILE="$sessions_file"
export FAKE_TMUX_TARGETS_FILE="$targets_file"
export FAKE_TMUX_COMMANDS_FILE="$commands_file"

touch "$call_log" "$sessions_file" "$targets_file" "$commands_file"

assert_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    echo "$label: expected to find '$needle'" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

assert_not_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    echo "$label: did not expect to find '$needle'" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

assert_no_create_calls() {
  local label="$1"

  if grep -Eq '(^| )(new-session|new-window|split-window)( |$)' "$call_log"; then
    echo "$label: rearm_timer attempted to create tmux state" >&2
    cat "$call_log" >&2
    exit 1
  fi
}

make_repo() {
  local repo="$1"
  local session_line="$2"

  mkdir -p "$repo/.xsm-local"
  cat >"$repo/.xsm-local/swarm-backlog.yaml" <<EOF
agents:
  - name: main
    driver: codex
    session: $session_line
    context:
      role: supervisor
EOF
  cat >"$repo/swarm-state.yaml" <<'EOF'
updated_at: "2026-04-29T00:00:00Z"
wrangle_count: 1
EOF
}

reset_fake() {
  : >"$call_log"
  : >"$sessions_file"
  : >"$targets_file"
  : >"$commands_file"
}

# Missing legacy xc-crew-earthshot succeeds by using the configured current
# supervisor window and its utility shell pane.
repo1="$tmpdir/repo1"
make_repo "$repo1" "xc:supervisor"
reset_fake
printf 'xc\n' >"$sessions_file"
printf 'xc:supervisor.1\nxc:supervisor.2\n' >"$targets_file"
printf 'xc:supervisor.1 node\nxc:supervisor.2 zsh\n' >"$commands_file"

XENOTA_REPO="$repo1" "$script_dir/rearm_timer.sh" 30 "$repo1/swarm-state.yaml"
log="$(cat "$call_log")"
assert_contains "configured-timer-target" "clear-history -t xc:supervisor.2" "$log"
assert_contains "configured-respawn-target" "respawn-pane -k -t xc:supervisor.2" "$log"
assert_contains "configured-worker-target" "send_worker_message.sh main" "$log"
assert_not_contains "no-legacy-session" "xc-crew-earthshot" "$log"
assert_no_create_calls "configured supervisor"

# If the config lacks a usable supervisor session, fall back to the current xc
# supervisor layout rather than creating the legacy session.
repo2="$tmpdir/repo2"
make_repo "$repo2" "missing:supervisor"
reset_fake
printf 'xc\n' >"$sessions_file"
printf 'xc:supervisor.1\nxc:supervisor.3\n' >"$targets_file"
printf 'xc:supervisor.1 node\nxc:supervisor.3 zsh\n' >"$commands_file"

XENOTA_REPO="$repo2" "$script_dir/rearm_timer.sh" 30 "$repo2/swarm-state.yaml"
log="$(cat "$call_log")"
assert_contains "layout-timer-target" "clear-history -t xc:supervisor.3" "$log"
assert_contains "layout-worker-target" "send_worker_message.sh main" "$log"
assert_not_contains "layout-no-legacy-session" "xc-crew-earthshot" "$log"
assert_no_create_calls "current xc layout"

# Every fifth pass uses restart_wrangle.sh and only needs a safe timer pane.
# This covers the numeric current-xc utility pane fallback from the incident.
repo3="$tmpdir/repo3"
make_repo "$repo3" "missing:supervisor"
cat >"$repo3/swarm-state.yaml" <<'EOF'
updated_at: "2026-04-29T00:00:00Z"
wrangle_count: 4
EOF
reset_fake
printf 'xc\n' >"$sessions_file"
printf 'xc:0.3\n' >"$targets_file"
printf 'xc:0.3 zsh\n' >"$commands_file"

XENOTA_REPO="$repo3" "$script_dir/rearm_timer.sh" 30 "$repo3/swarm-state.yaml"
log="$(cat "$call_log")"
assert_contains "numeric-utility-timer" "clear-history -t xc:0.3" "$log"
assert_contains "restart-mode" "restart_wrangle.sh" "$log"
assert_not_contains "restart-mode-no-send-worker" "send_worker_message.sh" "$log"
assert_not_contains "numeric-no-legacy-session" "xc-crew-earthshot" "$log"
assert_no_create_calls "numeric current xc utility"

# Single-rig: if xc-crew-earthshot is missing and xc is available, use xc:0.2
repo4="$tmpdir/repo4"
make_repo "$repo4" "missing:supervisor"
reset_fake
printf 'xc\n' >"$sessions_file"
printf 'xc:0.0\nxc:0.2\n' >"$targets_file"
printf 'xc:0.0 node\nxc:0.2 zsh\n' >"$commands_file"
# Note: resolve_rearm_timer_target fallbacks to resolve_earthshot_timer_target
# which now should use xc:0.2 if xc-crew-earthshot is missing.

XENOTA_REPO="$repo4" "$script_dir/rearm_timer.sh" 30 "$repo4/swarm-state.yaml"
log="$(cat "$call_log")"
assert_contains "single-rig-timer" "clear-history -t xc:0.2" "$log"
assert_contains "single-rig-worker" "send_worker_message.sh main" "$log"
assert_no_create_calls "single rig fallback"

echo "test_rearm_timer: OK"
