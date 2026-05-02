#!/usr/bin/env bash
set -euo pipefail

# Start the supervisor and landing lanes after a tmux server restart.
# xsm wrangle does NOT auto-respawn these (by design — they are human-managed
# per role_packages.{supervisor,landing}.routing_posture in the strategy).
# This script is the operator's "one-time after restart" companion to
# restart_local_xsm.sh.
#
# Each lane:
#   1. Opens the worktree as a tmux window (workmux open) if missing
#   2. Renames the window to the bare role name (xsm expects xc:supervisor not xc:" supervisor")
#   3. Replaces the default-agent pane (claude) with codex carrying the role's startup prompt

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"
source "$script_dir/resolve_repo_root.sh"
if ! repo_root="$(resolve_xenota_repo_root "$script_dir")"; then
  echo "start_supervisor_and_landing: could not locate live xenota repo root with .xsm-local/swarm-backlog.yaml from $script_dir; set XENOTA_REPO to override" >&2
  exit 1
fi

session="${1:-xc}"

# Read role startup prompts from the strategy file used by xsm.
# The supervisor/landing command allowlists live in the corresponding
# role_packages.<role>.startup_prompt text in that strategy. To allow a new
# maintenance command, add it there, restart the lane with this script, and
# verify the pane shows bypass permissions plus a successful command run.
# Use awk (POSIX) instead of pyyaml so this works on a fresh box.
strategy_path="$repo_root/.xsm-local/strategies/live-backlog.yaml"
if [[ ! -f "$strategy_path" ]]; then
  echo "start_supervisor_and_landing: missing strategy: $strategy_path" >&2
  exit 1
fi

extract_prompt() {
  # Pulls startup_prompt + standing_orders from a role_packages entry and joins
  # them into a single launch prompt. Without standing_orders codex executes
  # one cycle and idles; with them it loops on its role until the queue empties.
  local role="$1"
  awk -v role="$role" '
    BEGIN { state = 0; sp = ""; orders = "" }
    $0 ~ "^  "role":" { state = 1; next }
    state == 1 && /^[a-zA-Z]/ { state = 0 }
    state == 1 && /^  [a-zA-Z]/ && !/^    / { state = 0 }
    state == 1 && /^    startup_prompt:/ {
      line = $0
      sub(/^    startup_prompt: *"?/, "", line)
      sub(/"$/, "", line)
      sp = line
    }
    state == 1 && /^    standing_orders:/ { in_orders = 1; next }
    state == 1 && in_orders && /^      - / {
      line = $0
      sub(/^      - *"?/, "", line)
      sub(/"$/, "", line)
      orders = orders "- " line "\n"
      next
    }
    state == 1 && in_orders && !/^      / { in_orders = 0 }
    END {
      if (sp != "") {
        print sp
        if (orders != "") {
          print ""
          print "Standing orders (loop on these until you have nothing left to do):"
          printf "%s", orders
        }
      }
    }
  ' "$strategy_path"
}

ensure_lane() {
  local role="$1"
  local worktree="$2"
  local target="$session:$role"
  local startup_prompt
  startup_prompt="$(extract_prompt "$role")"

  if [[ -z "$startup_prompt" ]]; then
    echo "start_supervisor_and_landing: no startup_prompt for role '$role' in strategy" >&2
    return 1
  fi

  # Does the window already exist (with bare or leading-space name)?
  local idx
  idx="$(
    "${tmux_cmd[@]}" list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null \
    | awk -F: -v r="$role" '$2 == r || $2 == " "r {print $1; exit}'
  )"
  if [[ -z "$idx" ]]; then
    workmux open "$worktree" >/dev/null 2>&1 || true
    sleep 1
    idx="$(
      "${tmux_cmd[@]}" list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null \
      | awk -F: -v r="$role" '$2 == r || $2 == " "r {print $1; exit}'
    )"
  fi
  if [[ -z "$idx" ]]; then
    echo "start_supervisor_and_landing: failed to find window for $role" >&2
    return 1
  fi
  "${tmux_cmd[@]}" rename-window -t "$session:$idx" "$role"

  # Agent pane target: .0 by default, .1 if a workmux sidebar occupies .0.
  # Newer workmux versions inject a sidebar pane at index 0 (pane_current_command=workmux)
  # which shifts the agent pane to index 1. Older layouts put the agent in .0 directly.
  local pane0_cmd
  pane0_cmd="$(tmux_pane_current_command "$session:$role.0" 2>/dev/null || echo "")"
  local agent_pane
  if [[ "$pane0_cmd" == "workmux" ]]; then
    agent_pane="$session:$role.1"
  else
    agent_pane="$session:$role.0"
  fi
  local current_cmd
  current_cmd="$(tmux_pane_current_command "$agent_pane" 2>/dev/null || echo "")"

  if [[ "$current_cmd" == "codex" || "$current_cmd" == "node" ]]; then
    echo "start_supervisor_and_landing: $agent_pane already running $current_cmd"
    return 0
  fi

  # Forcibly reset the pane (kills whatever's in it — claude, etc.) and start codex.
  "${tmux_cmd[@]}" respawn-pane -k -t "$agent_pane" -c "$repo_root/.worktrees/$worktree" \
    "$default_shell" 2>/dev/null || true
  sleep 1

  # Short bootstrap prompt: tell codex to read its own role definition from the
  # strategy file. This avoids multiline/quote issues with sending a long
  # startup_prompt via tmux send-keys (the old approach hit shell-quoting
  # continuation bugs and dumped the prompt text into the pane raw).
  #
  # --dangerously-bypass-approvals-and-sandbox: required for autonomous operation.
  # Externally sandboxed (operator-controlled tmux + worktree).
  local bootstrap
  bootstrap="Read $strategy_path section role_packages.$role for your startup_prompt and standing_orders. Follow them exactly. Loop on your role's work continuously. ZERO HUMAN APPROVAL GATES — you carry merge/dispatch/decision authority in-band per the manage-swarm prime directive. Never park at 'waiting for human approval' while a gate ledger is satisfied; that is a catastrophic gate failure. An empty input prompt or codex placeholder line (e.g. '› Summarize recent commits', '› Write tests for @filename', '› Use /skills to list available skills', '› Run /review on my current changes', '› Implement {feature}') is NOT a stop condition — it is a parked_unassigned signal that you must immediately answer by re-entering the patrol loop. Never halt at an input prompt unless a standing_order explicitly requires it."
  local quoted_bootstrap
  quoted_bootstrap="$(printf '%s' "$bootstrap" | sed "s/'/'\\\\''/g")"
  tmux_send_literal_text "$agent_pane" "codex --dangerously-bypass-approvals-and-sandbox '$quoted_bootstrap'"
  tmux_send_raw_keys "$agent_pane" Enter
  echo "start_supervisor_and_landing: launched codex in $agent_pane"
}

ensure_lane supervisor supervisor
ensure_lane landing landing

echo "start_supervisor_and_landing: complete"
