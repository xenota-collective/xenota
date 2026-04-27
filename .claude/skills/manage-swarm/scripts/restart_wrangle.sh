#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"
target="$(resolve_earthshot_worker_target)"

wait_for_text() {
  local needle="$1"
  tmux_wait_for_text "$target" "$needle" 10
}

kickoff_instruction='read the manage-swarm skill, then wrangle the swarm'

reset_rc=0
tmux_reset_session "$target" || reset_rc=$?
case "$reset_rc" in
  0)
    ;;
  1)
    echo "restart_wrangle: /clear did not settle cleanly on $target" >&2
    tmux_recent_pane_text "$target" >&2
    exit 1
    ;;
  2)
    echo "restart_wrangle: $target was at a shell prompt and claude could not be re-launched" >&2
    tmux_recent_pane_text "$target" >&2
    exit 1
    ;;
  3)
    echo "restart_wrangle: $target family=$(tmux_pane_family "$target") has no reset path; operator recovery required" >&2
    tmux_recent_pane_text "$target" >&2
    exit 1
    ;;
  *)
    echo "restart_wrangle: tmux_reset_session failed on $target with rc=$reset_rc" >&2
    tmux_recent_pane_text "$target" >&2
    exit 1
    ;;
esac

tmux_send_prompt_line "$target" "$kickoff_instruction"

if ! wait_for_text "$kickoff_instruction"; then
  echo "restart_wrangle: kickoff instruction did not appear in $target after reset" >&2
  tmux_recent_pane_text "$target" >&2
  exit 1
fi

echo "restart_wrangle: kickoff instruction delivered, waiting for XSM to start and stabilize..."

repo_root="$(cd "$script_dir/../../../../" && pwd)"
xsm_bin="$repo_root/xenon/packages/xsm/.venv/bin/xsm"
xsm_config="$repo_root/.xsm-local/swarm-backlog.yaml"
monitor_timeout_bin="${XSM_MONITOR_TIMEOUT_BIN:-}"

if [[ ! -x "$xsm_bin" ]]; then
  # Fallback to PATH if .venv not found or not executable
  xsm_bin="xsm"
fi

if [[ -z "$monitor_timeout_bin" ]]; then
  if command -v timeout >/dev/null 2>&1; then
    monitor_timeout_bin="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    monitor_timeout_bin="gtimeout"
  else
    echo "restart_wrangle: timeout command not found; cannot bound xsm monitor health checks" >&2
    exit 1
  fi
fi

# Wait up to 60s for health
for i in {1..12}; do
  sleep 5
  if "$monitor_timeout_bin" 8 "$xsm_bin" monitor --config "$xsm_config" --once --json > "$repo_root/.xsm-local/log/restart_health.json" 2>/dev/null; then
    status="$(jq -r '.status' "$repo_root/.xsm-local/log/restart_health.json")"
    if [[ "$status" == "ready" ]]; then
      # Check if any workers are in bad states
      bad_workers="$(jq -r '.state_counts | to_entries[] | select(.key == "stopped" or .key == "respawn_needed") | .value' "$repo_root/.xsm-local/log/restart_health.json" | awk '{sum+=$1} END {print sum}')"
      if [[ "${bad_workers:-0}" -eq 0 ]]; then
        echo "restart_wrangle: XSM is healthy and all workers are active."
        exit 0
      else
        echo "restart_wrangle: XSM is ready but $bad_workers workers need attention (stopped/respawn_needed). Waiting..."
      fi
    else
      echo "restart_wrangle: XSM status is $status. Waiting..."
    fi
  else
    echo "restart_wrangle: xsm monitor failed or timed out. Waiting..."
  fi
done

echo "restart_wrangle: health check timed out. XSM may still be starting or requires manual intervention." >&2
exit 1
