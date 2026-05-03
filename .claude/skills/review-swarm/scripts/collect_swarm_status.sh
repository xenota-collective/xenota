#!/bin/bash
# Collects all deterministic signals for a swarm review:
#   - xsm process + daemon pane
#   - latest wrangle run events + leader escalations
#   - worker pane snapshots
#   - swarm-backlog.yaml + live pane mapping
#   - xr repertoire smoke check
#   - bd open beads
#   - open PRs in xenota, xenon, and handbook
#
# Prints a single plain-text section-delimited report on stdout.
# Does NOT mutate any state.
#
# Usage: collect_swarm_status.sh [repo-root]
#   repo-root: path to xenota repo (default: $PWD)

set -uo pipefail

REPO_ROOT="${1:-$PWD}"
TMUX_BIN="${TMUX_BIN:-/opt/homebrew/bin/tmux}"
TMUX_SOCKET="${TMUX_SOCKET:-/private/tmp/tmux-501/default}"
TMUX_SESSION="${TMUX_SESSION:-xc}"
PANE_LINES="${PANE_LINES:-30}"

[ -d "$REPO_ROOT" ] || { echo "Error: repo-root '$REPO_ROOT' not found" >&2; exit 1; }
cd "$REPO_ROOT" || exit 1

XSM_DIR="$REPO_ROOT/.xsm-local"
RUNS_DIR="$XSM_DIR/log/swarm-backlog/wrangle-runs"
CONFIG_YAML="$XSM_DIR/swarm-backlog.yaml"
LEADER_LOG="$XSM_DIR/leader-backlog.jsonl"

command -v "$TMUX_BIN" >/dev/null 2>&1 || { echo "Error: tmux not found at $TMUX_BIN" >&2; exit 1; }

TMUX=("$TMUX_BIN" "-S" "$TMUX_SOCKET")

section() { printf '\n===== %s =====\n' "$1"; }

# ------------------------------------------------------------------
section "XSM PROCESS"
pgrep -af 'python.*xsm|/xsm ' 2>/dev/null | grep -v -i helper || echo "(no xsm process found)"

# ------------------------------------------------------------------
section "XSM DAEMON PANE (xc:0.2, last $PANE_LINES lines)"
if "${TMUX[@]}" has-session -t "$TMUX_SESSION" 2>/dev/null; then
  "${TMUX[@]}" capture-pane -pt "${TMUX_SESSION}:0.2" -S "-${PANE_LINES}" 2>/dev/null || echo "(xc:0.2 not found)"
else
  echo "(tmux session '$TMUX_SESSION' not found)"
fi

# ------------------------------------------------------------------
section "LATEST WRANGLE RUN"
if [ -d "$RUNS_DIR" ]; then
  RUN=$(ls -t "$RUNS_DIR" 2>/dev/null | head -1)
  if [ -n "$RUN" ]; then
    EVENTS="$RUNS_DIR/$RUN/events.jsonl"
    RUN_META="$RUNS_DIR/$RUN/run.json"
    echo "run_id: $RUN"
    [ -f "$RUN_META" ] && cat "$RUN_META"
    if [ -f "$EVENTS" ]; then
      EVENT_COUNT=$(wc -l <"$EVENTS" 2>/dev/null | tr -d ' ')
      echo "events: $EVENT_COUNT lines"
      echo "events file: $EVENTS"
    fi
  else
    echo "(no runs found in $RUNS_DIR)"
  fi
else
  echo "(runs dir $RUNS_DIR not found)"
fi

# ------------------------------------------------------------------
section "NON-NOOP EVENTS (last 30)"
if [ -n "${EVENTS:-}" ] && [ -f "$EVENTS" ]; then
  grep -v '"action_count": 0' "$EVENTS" 2>/dev/null | tail -30
else
  echo "(no events file)"
fi

# ------------------------------------------------------------------
section "LEADER-BACKLOG ESCALATIONS (last 30)"
if [ -f "$LEADER_LOG" ]; then
  tail -30 "$LEADER_LOG"
else
  echo "(no leader-backlog.jsonl)"
fi

# ------------------------------------------------------------------
section "RESET_AND_ASSIGN REPETITION CHECK"
# Count occurrences of reset_and_assign per agent+bead combo across last 500 non-noop events.
if [ -n "${EVENTS:-}" ] && [ -f "$EVENTS" ]; then
  grep '"action_type": "reset_and_assign"' "$EVENTS" 2>/dev/null | tail -500 |
    grep -oE '"agent": "[^"]*"[^}]*"bead_id": "[^"]*"' |
    sed -E 's/"agent": "([^"]*)".*"bead_id": "([^"]*)"/\1 \2/' |
    sort | uniq -c | sort -rn | head -10
  echo "(format: count agent bead — 3+ is suspicious)"
else
  echo "(no events file to scan)"
fi

# ------------------------------------------------------------------
section "WORKER PANE SNAPSHOTS"
# Discover which windows exist; capture .1 of each worker window.
if "${TMUX[@]}" has-session -t "$TMUX_SESSION" 2>/dev/null; then
  "${TMUX[@]}" list-windows -t "$TMUX_SESSION" -F '#{window_index} #{window_name}' 2>/dev/null |
    while read -r idx name; do
      case "$name" in
        worker-*|wrangler|worker-*-*)
          target="${TMUX_SESSION}:${idx}.1"
          echo "----- $target ($name) -----"
          "${TMUX[@]}" capture-pane -pt "$target" -S "-${PANE_LINES}" 2>/dev/null || echo "(capture failed)"
          ;;
      esac
    done
else
  echo "(tmux session '$TMUX_SESSION' not found)"
fi

# ------------------------------------------------------------------
section "SWARM-BACKLOG.YAML"
if [ -f "$CONFIG_YAML" ]; then
  cat "$CONFIG_YAML"
else
  echo "(no $CONFIG_YAML)"
fi

# ------------------------------------------------------------------
section "XR REPERTOIRE SMOKE CHECK"
if [ -f "$CONFIG_YAML" ]; then
  REPERTOIRE=$(awk '/^repertoire:/ {print $2; exit}' "$CONFIG_YAML")
  if [ -n "$REPERTOIRE" ]; then
    REP_ABS=$(cd "$(dirname "$CONFIG_YAML")" && cd "$REPERTOIRE" 2>/dev/null && pwd)
    if [ -n "$REP_ABS" ]; then
      echo "repertoire: $REP_ABS"
      if command -v xr >/dev/null 2>&1; then
        xr -p "$REP_ABS" list 2>&1 | head -20
      else
        echo "(xr binary not on PATH)"
      fi
    else
      echo "(repertoire path '$REPERTOIRE' does not resolve)"
    fi
  else
    echo "(no repertoire: field in yaml)"
  fi
fi

# ------------------------------------------------------------------
section "BEAD BACKLOG (open, top 40 by priority)"
if command -v bd >/dev/null 2>&1; then
  bd list --state=open --flat 2>/dev/null | head -40 || echo "(bd list failed)"
else
  echo "(bd binary not on PATH)"
fi

# ------------------------------------------------------------------
section "OPEN PRs — xenota"
if command -v gh >/dev/null 2>&1; then
  gh pr list -R xenota-collective/xenota --state=open \
    --json=number,title,author,isDraft,mergeable,updatedAt \
    --template '{{range .}}#{{.number}} {{.author.login}} [{{.mergeable}}]{{if .isDraft}} DRAFT{{end}} {{.title}}  (updated {{timefmt "2006-01-02" .updatedAt}}){{"\n"}}{{end}}' \
    2>&1 | head -40
else
  echo "(gh not on PATH)"
fi

section "OPEN PRs — xenon"
if command -v gh >/dev/null 2>&1; then
  gh pr list -R xenota-collective/xenon --state=open \
    --json=number,title,author,isDraft,mergeable,updatedAt \
    --template '{{range .}}#{{.number}} {{.author.login}} [{{.mergeable}}]{{if .isDraft}} DRAFT{{end}} {{.title}}  (updated {{timefmt "2006-01-02" .updatedAt}}){{"\n"}}{{end}}' \
    2>&1 | head -80
fi

section "OPEN PRs — handbook"
if command -v gh >/dev/null 2>&1; then
  gh pr list -R xenota-collective/handbook --state=open \
    --json=number,title,author,isDraft,mergeable,updatedAt \
    --template '{{range .}}#{{.number}} {{.author.login}} [{{.mergeable}}]{{if .isDraft}} DRAFT{{end}} {{.title}}  (updated {{timefmt "2006-01-02" .updatedAt}}){{"\n"}}{{end}}' \
    2>&1 | head -80
fi

# ------------------------------------------------------------------
section "END"
echo "Collected at: $(date -Iseconds)"
