#!/usr/bin/env bash
# loop_no_op_guard.sh — pathology scanner for the wrangle loop.
#
# Reads recent xsm wrangle-runs and returns a verdict the wrangle loop should
# obey before running another tick. Designed to short-circuit "theatre of
# progress" — adjacent fixes shipped while the load-bearing pipeline is broken.
#
# Exit codes:
#   0  OK         — proceed with the wrangle tick
#   1  WARN       — pathological metric repeating; STOP shipping side fixes,
#                    file/update a P0 bead for that metric, do not layer adjacent
#                    fixes onto a broken pipeline
#   2  KILL       — two consecutive no-op ticks or three stuck ticks; STOP the
#                    loop now (CronDelete or /loop stop) and surface to operator
#                    with options
#
# Usage:
#   loop_no_op_guard.sh [--repo <path>] [--runs <n>]
#
# Defaults: repo=/Users/jv/projects/xenota, runs=5 (last 5 wrangle-runs).

set -euo pipefail

REPO="${REPO:-/Users/jv/projects/xenota}"
RUNS=5
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --runs) RUNS="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 64 ;;
  esac
done

WRANGLE_DIR="$REPO/.xsm-local/log/swarm-backlog/wrangle-runs"
if [[ ! -d "$WRANGLE_DIR" ]]; then
  echo "no wrangle-runs at $WRANGLE_DIR — nothing to guard against" >&2
  exit 0
fi

# Collect the latest N runs that have an events.jsonl
mapfile -t RECENT < <(
  ls -t "$WRANGLE_DIR" 2>/dev/null \
    | while IFS= read -r dir; do
        f="$WRANGLE_DIR/$dir/events.jsonl"
        [[ -s "$f" ]] && echo "$f"
      done \
    | head -n "$RUNS"
)

if (( ${#RECENT[@]} == 0 )); then
  echo "no recent runs with events.jsonl — first tick or fresh restart" >&2
  exit 0
fi

# --- Pathological metric scan: budget exhaustion ---
BUDGET_HITS=0
for f in "${RECENT[@]}"; do
  if grep -q "observation pass exceeded budget" "$f" 2>/dev/null; then
    BUDGET_HITS=$((BUDGET_HITS + 1))
  fi
done

# --- Pathological metric scan: interrupt_guard_blocked recurrence ---
GUARD_HITS=0
for f in "${RECENT[@]}"; do
  if jq -e -c 'select(.event_type=="action_status" and .failure_kind=="interrupt_guard_blocked")' "$f" >/dev/null 2>&1; then
    GUARD_HITS=$((GUARD_HITS + 1))
  fi
done

# --- No-op tick: an action_status pass that took NO interventions on any worker ---
# A no-op = wrangle pass that emitted only escalate / cannot_intervene actions
# and zero of: nudge / send_keys / send_prompt_line / reset_and_assign / restart_session.
NO_OP_TICKS=0
for f in "${RECENT[@]}"; do
  attempted_action_types=$(jq -r 'select(.event_type=="action_status" and .status=="attempted") | .action.action_type' "$f" 2>/dev/null | sort -u)
  if [[ -n "$attempted_action_types" ]] && \
     ! echo "$attempted_action_types" | grep -qE '^(nudge|send_keys|send_prompt_line|reset_and_assign|restart_session)$'; then
    NO_OP_TICKS=$((NO_OP_TICKS + 1))
  fi
done

# --- Identical-idle-pattern: same agent stuck in same state across all recent runs ---
STUCK_AGENTS=$(
  for f in "${RECENT[@]}"; do
    jq -r 'select(.event_type=="wrangle_pass") | .snapshot.agents[] | "\(.name)\t\(.state)"' "$f" 2>/dev/null
  done | sort | uniq -c | awk -v n="${#RECENT[@]}" '$1 >= n && $3 != "active_working" {print $2 " " $3}'
)
STUCK_COUNT=$(echo -n "$STUCK_AGENTS" | grep -c . || true)

# --- Verdict ---
echo "loop_no_op_guard: runs=${#RECENT[@]} budget_hits=$BUDGET_HITS guard_hits=$GUARD_HITS no_op_ticks=$NO_OP_TICKS stuck_agents=$STUCK_COUNT"
[[ -n "$STUCK_AGENTS" ]] && echo "stuck:" && echo "$STUCK_AGENTS"

# KILL conditions (rc=2)
if (( NO_OP_TICKS >= 2 )); then
  echo "VERDICT: KILL — $NO_OP_TICKS consecutive no-op ticks. Stop the loop and surface options to the operator." >&2
  exit 2
fi
if (( STUCK_COUNT >= 1 )) && (( ${#RECENT[@]} >= 3 )); then
  echo "VERDICT: KILL — agent(s) stuck in identical non-working state across $RUNS runs." >&2
  exit 2
fi

# WARN conditions (rc=1)
if (( BUDGET_HITS >= 2 )); then
  echo "VERDICT: WARN — observation_budget_exhaustion in $BUDGET_HITS of last ${#RECENT[@]} runs. THIS IS THE LOAD-BEARING P0. Stop adjacent fixes; either fix the budget pipeline or escalate." >&2
  exit 1
fi
if (( GUARD_HITS >= 2 )); then
  echo "VERDICT: WARN — interrupt_guard_blocked in $GUARD_HITS of last ${#RECENT[@]} runs. File/update P0 bead for the specific lane + state combination." >&2
  exit 1
fi

echo "VERDICT: OK"
exit 0
