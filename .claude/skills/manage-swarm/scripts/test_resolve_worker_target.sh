#!/usr/bin/env bash
# Regression coverage for xc-lvy8t: resolve_worker_target must find the
# active agent pane instead of assuming .1.
#
# We don't require a live tmux server. Instead we stub the tmux binary
# with a small shell script that answers list-panes / display-message
# from a fixture file the test writes per-case. resolve_worker_target
# uses ${TMUX_BIN}, so we point that at the stub.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

stub_path="${fixture_dir}/tmux"
fixture_path="${fixture_dir}/panes"

# Tmux stub. Reads ${fixture_path} which is a CSV of:
#   pane_index,pane_current_command,pane_width
# Plus a sentinel first line "session=<name>" so list-panes -t and
# has-session can answer.
cat >"$stub_path" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

fixture="${TMUX_TARGET_FIXTURE:?stub: TMUX_TARGET_FIXTURE not set}"

read_session_name() {
  awk -F= '$1=="session" {print $2; exit}' "$fixture"
}

read_panes() {
  awk -F, '$1!="session" {print}' "$fixture"
}

session_name="$(read_session_name)"

# Parse target like "xc:worker-codex-1.0" or "xc:worker-codex-1" or "xc"
parse_target() {
  local raw="$1"
  local sess win pane
  sess="${raw%%:*}"
  if [[ "$raw" == *:* ]]; then
    local rest="${raw#*:}"
    if [[ "$rest" == *.* ]]; then
      win="${rest%.*}"
      pane="${rest##*.}"
    else
      win="$rest"
      pane=""
    fi
  else
    win=""
    pane=""
  fi
  printf '%s\n%s\n%s\n' "$sess" "$win" "$pane"
}

cmd="$1"
shift

case "$cmd" in
  has-session)
    # has-session -t <session>
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -t) shift; target="$1"; shift ;;
        *) shift ;;
      esac
    done
    [[ "$target" == "$session_name" ]]
    exit $?
    ;;
  list-panes)
    target=""
    fmt=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -t) shift; target="$1"; shift ;;
        -F) shift; fmt="$1"; shift ;;
        *) shift ;;
      esac
    done
    parsed=$(parse_target "$target")
    sess=$(awk 'NR==1' <<<"$parsed")
    win=$(awk 'NR==2' <<<"$parsed")
    pane=$(awk 'NR==3' <<<"$parsed")
    if [[ "$sess" != "$session_name" ]]; then
      exit 1
    fi
    # If a specific pane was named, only output that pane (or fail).
    while IFS=, read -r p_idx p_cmd p_width; do
      if [[ -z "$pane" || "$pane" == "$p_idx" ]]; then
        case "$fmt" in
          *'pane_current_command'*)
            printf '%s %s\n' "$p_idx" "$p_cmd"
            ;;
          *'window_index'*'pane_index'*)
            printf '0.%s\n' "$p_idx"
            ;;
          *'pane_index'*)
            printf '%s\n' "$p_idx"
            ;;
          *)
            printf '%s\n' "$p_idx"
            ;;
        esac
      fi
    done < <(read_panes)
    if [[ -n "$pane" ]]; then
      # If the specified pane doesn't exist, list-panes returns 1.
      if ! grep -q "^${pane}," <<<"$(read_panes)"; then
        exit 1
      fi
    fi
    exit 0
    ;;
  display-message)
    target=""
    print_only=0
    fmt=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -p) print_only=1; shift ;;
        -t) shift; target="$1"; shift ;;
        *) fmt="$1"; shift ;;
      esac
    done
    parsed=$(parse_target "$target")
    sess=$(awk 'NR==1' <<<"$parsed")
    pane=$(awk 'NR==3' <<<"$parsed")
    if [[ "$sess" != "$session_name" ]]; then
      exit 1
    fi
    pane_line=$(grep "^${pane}," "$fixture" || true)
    if [[ -z "$pane_line" ]]; then
      exit 1
    fi
    p_cmd=$(awk -F, '{print $2}' <<<"$pane_line")
    p_width=$(awk -F, '{print $3}' <<<"$pane_line")
    case "$fmt" in
      *'pane_current_command'*) printf '%s\n' "$p_cmd" ;;
      *'pane_width'*) printf '%s\n' "$p_width" ;;
      *'pane_title'*) printf 'pane-%s\n' "$pane" ;;
      *'pane_start_command'*) printf '\n' ;;
      *) printf '\n' ;;
    esac
    exit 0
    ;;
  capture-pane)
    # Used by tmux_pane_family second-pass. Return empty so family
    # falls back to current_command-based classification.
    printf ''
    exit 0
    ;;
  *)
    printf 'stub-tmux: unsupported subcommand: %s\n' "$cmd" >&2
    exit 2
    ;;
esac
STUB
chmod +x "$stub_path"

export TMUX_BIN="$stub_path"
export TMUX_TARGET_FIXTURE="$fixture_path"

# Source the resolver under test against the stubbed tmux.
source "$script_dir/tmux_target.sh"

failures=0
PASS=0

assert_resolves_to() {
  local label="$1"
  local worker="$2"
  local expected="$3"
  local got
  got="$(resolve_worker_target "$worker" || true)"
  if [[ "$got" == "$expected" ]]; then
    PASS=$((PASS + 1))
  else
    echo "FAIL: $label" >&2
    echo "  worker=$worker expected=$expected got=$got" >&2
    failures=$((failures + 1))
  fi
}

# ---- Scenario 1: agent at .0, zsh at .1 (the xc-lvy8t bug case) ----
cat >"$fixture_path" <<EOF
session=xc
0,codex,200
1,zsh,200
EOF
assert_resolves_to "agent at .0 with zsh at .1 → resolver picks .0" \
  "worker-codex-1" "xc:worker-codex-1.0"

# ---- Scenario 2: workmux sidebar at .0, agent at .1 (legacy) ----
cat >"$fixture_path" <<EOF
session=xc
0,workmux,30
1,claude,200
EOF
assert_resolves_to "workmux sidebar at .0, claude at .1 → resolver picks .1" \
  "worker-claude-2" "xc:worker-claude-2.1"

# ---- Scenario 3: agent at .0 (gemini) plus 2 zsh sidepanes ----
cat >"$fixture_path" <<EOF
session=xc
0,gemini,200
1,zsh,200
2,zsh,200
3,zsh,200
EOF
assert_resolves_to "gemini at .0 with three zsh side panes → resolver picks .0" \
  "worker-gemini-1" "xc:worker-gemini-1.0"

# ---- Scenario 4: no agent anywhere — falls back to .1 (legacy) ----
cat >"$fixture_path" <<EOF
session=xc
0,zsh,200
1,zsh,200
EOF
assert_resolves_to "no agent running → falls back to .1 (legacy behaviour)" \
  "worker-stub" "xc:worker-stub.1"

# ---- Scenario 5: only .0 exists, no agent — falls back to .0 ----
cat >"$fixture_path" <<EOF
session=xc
0,zsh,200
EOF
assert_resolves_to "only one pane, no agent → falls back to .0" \
  "worker-solo" "xc:worker-solo.0"

# ---- Scenario 6: explicit target with .0 — passes through ----
cat >"$fixture_path" <<EOF
session=xc
0,codex,200
1,zsh,200
EOF
assert_resolves_to "explicit xc:worker-codex-1.0 target stays as-is" \
  "xc:worker-codex-1.0" "xc:worker-codex-1.0"

if (( failures > 0 )); then
  echo "$failures tests failed (out of $((PASS + failures)))" >&2
  exit 1
fi
echo "$PASS tests passed"
