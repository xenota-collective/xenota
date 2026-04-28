#!/usr/bin/env bash
# xc-twaa6: guarded relaunch loop for ``xsm wrangle``.
#
# xsm gracefully self-exits when its own source files (or submodule
# pointers it depends on) change so a fresh interpreter can pick up the
# new code. The graceful-exit signal is rc=75 (EX_TEMPFAIL — see
# xsm/main.py ``raise SystemExit(75)``); rc=0 is also treated as a clean
# exit. Without an external supervisor noticing and respawning, xsm
# stays down — workers keep moving but classification, escalation,
# fd-pressure detection, and pool-fill dispatch all stop.
#
# This loop wraps the ``xsm wrangle`` invocation so:
#   - graceful exits (rc=0 or rc=75) auto-relaunch after a short backoff
#   - other non-zero exits (real crashes) break the loop so failures stay visible
#   - a per-session restart cap prevents tight crash loops from looping
#     unbounded when the new code is actually broken
#
# Usage:
#   xsm_relaunch_loop XSM_BIN CONFIG_PATH [BACKOFF_SECONDS] [RESTART_CAP]
#
# Designed to be sourced by callers (e.g. restart_local_xsm.sh) or
# invoked directly for testing.

xsm_relaunch_loop() {
  local xsm_bin="${1:?xsm_relaunch_loop: missing xsm_bin}"
  local config_path="${2:?xsm_relaunch_loop: missing config_path}"
  local backoff="${3:-3}"
  local restart_cap="${4:-20}"

  local restarts=0
  local rc=0
  while true; do
    "$xsm_bin" wrangle --config "$config_path" --json
    rc=$?
    restarts=$((restarts + 1))
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 75 ]; then
      echo "xsm exited rc=$rc (non-graceful); not auto-restarting; restarts=$restarts"
      return "$rc"
    fi
    if [ "$restarts" -gt "$restart_cap" ]; then
      echo "xsm restart cap reached ($restarts in this session); refusing to loop further"
      return 0
    fi
    echo "xsm exited rc=$rc (graceful); relaunching in ${backoff}s; restarts=$restarts"
    sleep "$backoff"
  done
}

# When invoked as a standalone script (not sourced), run the loop with
# the provided arguments.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  xsm_relaunch_loop "$@"
fi
