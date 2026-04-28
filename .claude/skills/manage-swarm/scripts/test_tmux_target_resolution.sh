#!/usr/bin/env bash
set -euo pipefail

# Unit tests for tmux target resolution. The tmux binary is replaced with a
# deterministic fake so these checks cannot create real tmux sessions.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fake_tmux="$tmpdir/tmux"
fake_workmux="$tmpdir/workmux"
call_log="$tmpdir/calls.log"
sessions_file="$tmpdir/sessions"
targets_file="$tmpdir/targets"
workmux_data_file="$tmpdir/workmux_data"

cat >"$fake_tmux" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${FAKE_TMUX_CALL_LOG:?}"

has_line() {
  local file="$1"
  local needle="$2"
  [[ -f "$file" ]] && grep -Fxq "$needle" "$file"
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
    if [[ "$target" == @* || "$target" == %* || "$target" == *:*.* ]]; then
      if has_line "${FAKE_TMUX_TARGETS_FILE:?}" "$target" || grep -q "^$target " "${FAKE_TMUX_TARGETS_FILE:?}"; then
        exit 0
      fi
      exit 1
    fi
    session="${target%%:*}"
    if ! has_line "${FAKE_TMUX_SESSIONS_FILE:?}" "$session"; then
      exit 1
    fi
    if [[ "$format" == "#{pane_id}" ]]; then
      printf '%%0\n'
    elif [[ "$format" == "#S:#I.#P" ]]; then
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
      '#{pane_id}')
        grep "^$target " "${FAKE_TMUX_TARGETS_FILE:?}" | cut -d' ' -f2 || echo "%0"
        ;;
      '#{window_id}')
        grep "^$target " "${FAKE_TMUX_TARGETS_FILE:?}" | cut -d' ' -f3 || echo "@0"
        ;;
      '#S')
        grep "^$target " "${FAKE_TMUX_TARGETS_FILE:?}" | cut -d' ' -f4 || echo "xc"
        ;;
      '#I')
        grep "^$target " "${FAKE_TMUX_TARGETS_FILE:?}" | cut -d' ' -f5 || echo "0"
        ;;
      '#{pane_current_command}') printf 'node\n' ;;
      '#{pane_start_command}') printf 'node\n' ;;
      '#{pane_title}') printf 'node\n' ;;
      '#{pane_width}') printf '120\n' ;;
      *) printf '\n' ;;
    esac
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

cat >"$fake_workmux" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == "status" ]]; then
  handle="$2"
  grep "^$handle " "${FAKE_WORKMUX_DATA_FILE:?}" | cut -d' ' -f2-
fi
FAKE
chmod +x "$fake_workmux"

export TMUX_BIN="$fake_tmux"
export PATH="$tmpdir:$PATH"
export FAKE_TMUX_CALL_LOG="$call_log"
export FAKE_TMUX_SESSIONS_FILE="$sessions_file"
export FAKE_TMUX_TARGETS_FILE="$targets_file"
export FAKE_WORKMUX_DATA_FILE="$workmux_data_file"

touch "$call_log" "$sessions_file" "$targets_file" "$workmux_data_file"

source "$script_dir/tmux_target.sh"

reset_fake() {
  : >"$call_log"
  : >"$sessions_file"
  : >"$targets_file"
  : >"$workmux_data_file"
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

assert_fails() {
  local label="$1"
  shift

  if "$@" >/tmp/tmux-target-test.out 2>/tmp/tmux-target-test.err; then
    echo "$label: command unexpectedly succeeded" >&2
    cat /tmp/tmux-target-test.out >&2
    cat /tmp/tmux-target-test.err >&2
    exit 1
  fi
}

assert_no_create_calls() {
  local label="$1"

  if grep -Eq '(^| )(new-session|new-window|split-window)( |$)' "$call_log"; then
    echo "$label: resolver attempted to create tmux state" >&2
    cat "$call_log" >&2
    exit 1
  fi
}

reset_fake
assert_fails "missing named lane" resolve_named_lane_target "xc-crew-missing"
assert_no_create_calls "missing named lane"

reset_fake
assert_fails "missing current worker window" resolve_worker_target "worker-gemini-2"
assert_no_create_calls "missing current worker window"

reset_fake
assert_fails "double-prefixed worker handle" resolve_worker_target "xc-crew-last"
assert_no_create_calls "double-prefixed worker handle"

reset_fake
printf 'xc-crew-last\n' >"$sessions_file"
target="$(resolve_worker_target "last")"
assert_eq "legacy lane target" "%0" "$target"
assert_no_create_calls "legacy lane target"

reset_fake
printf 'xc:worker-claude-1.1\n' >"$sessions_file"
printf '%s %s\n' "xc:worker-claude-1.1" "%123" >"$targets_file"
target="$(resolve_worker_target "worker-claude-1")"
assert_eq "current worker target resolved to ID" "%123" "$target"
assert_no_create_calls "current worker target resolved to ID"

reset_fake
echo 'worker-1 [{"pane_id": "%99"}]' >"$workmux_data_file"
printf '%s\n' "%99" >"$targets_file"
target="$(resolve_worker_target "worker-1")"
assert_eq "resolve via workmux handle" "%99" "$target"
assert_no_create_calls "resolve via workmux handle"

reset_fake
echo 'worker-2 [{"window_id": "@5"}]' >"$workmux_data_file"
printf '%s.0\n' "@5" >"$targets_file"
target="$(resolve_worker_target "worker-2")"
assert_eq "resolve via workmux handle fallback to window_id" "@5.0" "$target"
assert_no_create_calls "resolve via workmux handle fallback to window_id"

reset_fake
printf '%s %s\n' "@42" "%4242" >"$targets_file"
target="$(resolve_worker_target "@42")"
assert_eq "resolve via window ID resolved to pane ID" "%4242" "$target"
assert_no_create_calls "resolve via window ID resolved to pane ID"


echo "test_tmux_target_resolution: OK"
