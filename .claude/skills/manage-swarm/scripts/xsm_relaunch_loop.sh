#!/usr/bin/env bash
# xc-twaa6 + xc-zmpda.3: guarded relaunch loop for ``xsm wrangle``.
#
# xsm gracefully self-exits when its own source files (or submodule
# pointers it depends on) change so a fresh interpreter can pick up the
# new code. The graceful-exit signal is rc=75 (EX_TEMPFAIL — see
# xsm/main.py ``raise SystemExit(75)``); rc=0 is also treated as a clean
# exit. xc-zmpda.3 adds rc=143 (128 + SIGTERM) to the graceful set so the
# fast-track post-merge auto-restart hook (restart_xsm.sh) can SIGTERM
# the running daemon and have the wrapper respawn it on the new code.
#
# Without an external supervisor noticing and respawning, xsm
# stays down — workers keep moving but classification, escalation,
# fd-pressure detection, and pool-fill dispatch all stop.
#
# This loop wraps the ``xsm wrangle`` invocation so:
#   - graceful exits (rc=0, rc=75, rc=143) auto-relaunch after a short backoff
#   - other non-zero exits (real crashes) break the loop so failures stay visible
#   - a per-session restart cap prevents tight crash loops from looping
#     unbounded when the new code is actually broken
#
# xc-zmpda.3 self-detection fallback: between iterations we record the
# xsm-affecting SHA from the xenon submodule. The next iteration logs
# whether the SHA changed and prints a one-line audit marker so the
# operator can correlate restarts with the merge that prompted them.
# This is defence-in-depth in case the post-merge hook in
# .claude/skills/land-submodule-stack misfires — the daemon will still
# pick up the new code at its next graceful exit.
#
# Usage:
#   xsm_relaunch_loop XSM_BIN CONFIG_PATH [BACKOFF_SECONDS] [RESTART_CAP]
#
# Environment overrides:
#   XSM_RELAUNCH_LOOP_SHA_CMD  command to print the current xsm-affecting
#                              SHA (default: ``git -C xenon log -1
#                              --format=%H -- packages/xsm/``). Set to ""
#                              to disable SHA tracking.
#   XSM_RELAUNCH_LOOP_AUDIT    audit-log path (default: stderr only).
#
# Designed to be sourced by callers (e.g. restart_local_xsm.sh) or
# invoked directly for testing.

xsm_relaunch_loop_xsm_sha() {
  local sha_cmd="${XSM_RELAUNCH_LOOP_SHA_CMD-git -C xenon log -1 --format=%H -- packages/xsm/}"
  if [[ -z "$sha_cmd" ]]; then
    echo ""
    return 0
  fi
  # Tolerate failures (no xenon checkout, missing path) — return empty.
  bash -c "$sha_cmd" 2>/dev/null || echo ""
}

xsm_relaunch_loop_audit() {
  local message="$1"
  local audit_path="${XSM_RELAUNCH_LOOP_AUDIT:-}"
  local ts
  ts="$(date -u +%FT%TZ 2>/dev/null || echo "unknown")"
  echo "${ts} xsm_relaunch_loop: ${message}" >&2
  if [[ -n "$audit_path" ]]; then
    mkdir -p "$(dirname "$audit_path")" 2>/dev/null || true
    echo "${ts} xsm_relaunch_loop: ${message}" >> "$audit_path" 2>/dev/null || true
  fi
}

xsm_relaunch_loop() {
  local xsm_bin="${1:?xsm_relaunch_loop: missing xsm_bin}"
  local config_path="${2:?xsm_relaunch_loop: missing config_path}"
  local backoff="${3:-3}"
  local restart_cap="${4:-20}"

  local restarts=0
  local rc=0
  local last_sha
  last_sha="$(xsm_relaunch_loop_xsm_sha)"
  if [[ -n "$last_sha" ]]; then
    xsm_relaunch_loop_audit "starting at sha=$last_sha"
  fi
  while true; do
    "$xsm_bin" wrangle --config "$config_path" --json
    rc=$?
    restarts=$((restarts + 1))
    # rc=0 (clean), rc=75 (EX_TEMPFAIL graceful self-exit), and rc=143
    # (128 + SIGTERM, used by restart_xsm.sh post-merge hook) are all
    # treated as graceful — auto-relaunch on the new code.
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 75 ] && [ "$rc" -ne 143 ]; then
      xsm_relaunch_loop_audit "exited rc=$rc (non-graceful); not auto-restarting; restarts=$restarts"
      return "$rc"
    fi
    if [ "$restarts" -gt "$restart_cap" ]; then
      xsm_relaunch_loop_audit "restart cap reached ($restarts in this session); refusing to loop further"
      return 0
    fi
    # SHA self-detection: log whether xsm-affecting code changed since the
    # last iteration. The wrapper will respawn xsm regardless (it's a
    # graceful exit) but this marker lets retros confirm the restart
    # picked up the expected merge.
    local current_sha
    current_sha="$(xsm_relaunch_loop_xsm_sha)"
    if [[ -n "$current_sha" && "$current_sha" != "$last_sha" ]]; then
      xsm_relaunch_loop_audit "xsm sha changed $last_sha -> $current_sha (rc=$rc; restarts=$restarts)"
      last_sha="$current_sha"
    else
      xsm_relaunch_loop_audit "exited rc=$rc (graceful); relaunching in ${backoff}s; restarts=$restarts"
    fi
    sleep "$backoff"
  done
}

# When invoked as a standalone script (not sourced), run the loop with
# the provided arguments.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  xsm_relaunch_loop "$@"
fi
