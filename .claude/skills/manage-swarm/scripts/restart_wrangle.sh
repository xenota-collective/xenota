#!/usr/bin/env bash
set -euo pipefail

restart_wrangle_health_status() {
  local health_json="$1"
  jq -er '.status // empty' <<<"$health_json"
}

restart_wrangle_bad_worker_count() {
  local health_json="$1"
  jq -er '
    (.state_counts | objects) as $counts
    | (($counts.stopped // 0) + ($counts.respawn_needed // 0))
  ' <<<"$health_json"
}

if [[ "${RESTART_WRANGLE_TEST_HELPERS_ONLY:-0}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"
source "$script_dir/resolve_repo_root.sh"
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

if ! repo_root="$(resolve_xenota_repo_root "$script_dir")"; then
  echo "restart_wrangle: could not locate live xenota repo root with .xsm-local/swarm-backlog.yaml from $script_dir; set XENOTA_REPO to override" >&2
  exit 1
fi
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

# Wait up to 60s for health. Capture monitor JSON in-process per iteration so
# concurrent restart_wrangle invocations cannot race on a shared file (xc-1xc8).
for i in {1..12}; do
  sleep 5
  if ! health_json="$("$monitor_timeout_bin" 8 "$xsm_bin" monitor --config "$xsm_config" --once --json 2>/dev/null)" \
      || [[ -z "$health_json" ]]; then
    echo "restart_wrangle: xsm monitor failed or timed out. Waiting..."
    continue
  fi
  if ! status="$(restart_wrangle_health_status "$health_json" 2>/dev/null)"; then
    echo "restart_wrangle: XSM health JSON missing or malformed status. Waiting..."
    continue
  fi
  if [[ "$status" == "ready" ]]; then
    # Check if any workers are in bad states
    if ! bad_workers="$(restart_wrangle_bad_worker_count "$health_json" 2>/dev/null)"; then
      echo "restart_wrangle: XSM health JSON missing or malformed state_counts. Waiting..."
      continue
    fi
    if [[ "${bad_workers:-0}" -eq 0 ]]; then
      echo "restart_wrangle: XSM is healthy and all workers are active."
      exit 0
    else
      echo "restart_wrangle: XSM is ready but $bad_workers workers need attention (stopped/respawn_needed). Waiting..."
    fi
  else
    echo "restart_wrangle: XSM status is $status. Waiting..."
  fi
done

echo "restart_wrangle: health check timed out. XSM may still be starting or requires manual intervention." >&2
exit 1
