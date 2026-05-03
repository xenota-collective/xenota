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
#   xsm_relaunch_loop XSM_BIN CONFIG_PATH [BACKOFF_SECONDS] [RESTART_CAP] [REPO_ROOT] [POLL_SECONDS]
#
# Designed to be sourced by callers (e.g. restart_local_xsm.sh) or
# invoked directly for testing.

xsm_relaunch_loop() {
  local xsm_bin="${1:?xsm_relaunch_loop: missing xsm_bin}"
  local config_path="${2:?xsm_relaunch_loop: missing config_path}"
  local backoff="${3:-3}"
  local restart_cap="${4:-20}"
  local repo_root="${5:-${XSM_RELAUNCH_REPO_ROOT:-}}"
  local poll_seconds="${6:-${XSM_RELAUNCH_POLL_SECONDS:-3}}"
  local debounce_seconds="${XSM_RELAUNCH_DEBOUNCE_SECONDS:-60}"

  local restarts=0
  local last_restart_time=0
  local now=0
  local rc=0
  local child_pid=""
  local packages_sha=""
  local current_packages_sha=""
  local path_restart="0"
  local resolved_config_path="$config_path"
  if [[ -f "$config_path" ]]; then
    resolved_config_path="$(cd "$(dirname "$config_path")" && pwd)/$(basename "$config_path")"
  fi
  if [[ -z "$repo_root" ]]; then
    repo_root="$(xsm_relaunch_infer_repo_root "$resolved_config_path")"
  fi
  packages_sha="$(xsm_relaunch_packages_sha "$repo_root")"

  while true; do
    path_restart="0"
    last_restart_time="$(date +%s)"
    "$xsm_bin" wrangle --config "$config_path" --json &
    child_pid="$!"
    while xsm_relaunch_child_running "$child_pid"; do
      if [[ "${XSM_RELAUNCH_DISABLE_PATH_POLL:-0}" != "1" && -n "$packages_sha" ]]; then
        sleep "$poll_seconds"
        current_packages_sha="$(xsm_relaunch_packages_sha "$repo_root")"
        if [[ -n "$current_packages_sha" && "$current_packages_sha" != "$packages_sha" ]]; then
          now="$(date +%s)"
          if (( now - last_restart_time < debounce_seconds )); then
            # xc-nf3i: suppress relaunch if we just restarted recently (thrash protection)
            continue
          fi
          echo "xsm packages/xsm sha changed ($packages_sha -> $current_packages_sha); terminating child for relaunch"
          xsm_relaunch_audit "$repo_root" "$resolved_config_path" "relaunch_loop_path_change" "$packages_sha" "$current_packages_sha" "$child_pid"
          kill -TERM "$child_pid" 2>/dev/null || true
          for _ in 1 2 3 4 5; do
            kill -0 "$child_pid" 2>/dev/null || break
            sleep 0.2
          done
          kill -0 "$child_pid" 2>/dev/null && kill -KILL "$child_pid" 2>/dev/null || true
          path_restart="1"
          packages_sha="$current_packages_sha"
          break
        fi
      else
        wait "$child_pid" || rc=$?
        child_pid=""
        break
      fi
    done
    if [[ -n "$child_pid" ]]; then
      rc=0
      wait "$child_pid" || rc=$?
      child_pid=""
    fi
    restarts=$((restarts + 1))
    if [[ "$path_restart" == "1" ]]; then
      rc=75
    fi
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 75 ] && [ "$rc" -ne 143 ]; then
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

xsm_relaunch_infer_repo_root() {
  local config_path="${1:-}"
  local config_dir=""
  if [[ -n "$config_path" ]]; then
    config_dir="$(dirname "$config_path")"
    if [[ "$(basename "$config_dir")" == ".xsm-local" ]]; then
      cd "$(dirname "$config_dir")" && pwd
      return 0
    fi
  fi
  pwd
}

xsm_relaunch_packages_sha() {
  local repo_root="${1:-}"
  [[ -n "$repo_root" && -d "$repo_root/xenon/.git" || -f "$repo_root/xenon/.git" ]] || return 0
  git -C "$repo_root/xenon" log -1 --format=%H -- packages/xsm/ 2>/dev/null || true
}

xsm_relaunch_child_running() {
  local pid="$1"
  local state=""

  kill -0 "$pid" 2>/dev/null || return 1
  state="$(ps -p "$pid" -o stat= 2>/dev/null || true)"
  [[ "$state" == Z* ]] && return 1
  return 0
}

xsm_relaunch_audit() {
  local repo_root="$1"
  local config_path="$2"
  local trigger="$3"
  local before_sha="$4"
  local after_sha="$5"
  local child_pid="$6"
  local audit_log="${XSM_RELAUNCH_AUDIT_LOG:-$repo_root/.xsm-local/log/xsm-restarts.jsonl}"
  mkdir -p "$(dirname "$audit_log")"
  jq -cn \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg trigger "$trigger" \
    --arg config_path "$config_path" \
    --arg before_sha "$before_sha" \
    --arg after_sha "$after_sha" \
    --arg child_pid "$child_pid" \
    '{timestamp:$ts,tool:"xsm_relaunch_loop",trigger:$trigger,config_path:$config_path,before_packages_xsm_sha:$before_sha,after_packages_xsm_sha:$after_sha,child_pid:($child_pid|tonumber? // $child_pid)}' \
    >>"$audit_log"
}

# When invoked as a standalone script (not sourced), run the loop with
# the provided arguments.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  xsm_relaunch_loop "$@"
fi
