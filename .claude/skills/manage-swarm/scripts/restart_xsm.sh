#!/usr/bin/env bash
set -euo pipefail

# xc-zmpda.3: Signal SIGTERM to the running ``xsm wrangle`` process so the
# xsm_relaunch_loop.sh wrapper respawns it on the new code.
#
# Why SIGTERM: xsm's relaunch loop now treats rc=143 (128 + SIGTERM) as a
# graceful exit just like rc=0 / rc=75, so a SIGTERM here is reaped by the
# wrapper and triggers an automatic relaunch within ~3s. This is the
# post-merge auto-restart path: when an xenota submodule-pointer PR lands a
# xenon SHA that touches packages/xsm/src/xsm/ or packages/xsm/pyproject.toml,
# the live xsm daemon must pick up the new code without operator action.
#
# Audit-logs every restart attempt to ``.xsm-local/restart_xsm.log`` with
# timestamp, target PIDs, exit status, and optional PR/SHA/source markers
# from the environment so retros can attribute every restart to the change
# that prompted it.
#
# Usage:
#   restart_xsm.sh [--config <path>] [--source <label>] [--pr <pr_ref>]
#                  [--sha <sha>] [--wait <seconds>] [--dry-run]
#
# Environment overrides:
#   XENOTA_REPO         live xenota repo root (auto-detected if unset)
#   RESTART_XSM_LOG     audit-log path (default: $repo_root/.xsm-local/restart_xsm.log)
#   RESTART_XSM_PS      ps invocation override (test seam)
#   RESTART_XSM_KILL    kill invocation override (test seam)

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

config_path=""
source_label="manual"
pr_ref=""
sha_ref=""
wait_seconds=10
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      config_path="${2:?--config requires a path}"; shift 2 ;;
    --source)
      source_label="${2:?--source requires a label}"; shift 2 ;;
    --pr)
      pr_ref="${2:?--pr requires a value}"; shift 2 ;;
    --sha)
      sha_ref="${2:?--sha requires a value}"; shift 2 ;;
    --wait)
      wait_seconds="${2:?--wait requires seconds}"; shift 2 ;;
    --dry-run)
      dry_run=1; shift ;;
    -h|--help)
      sed -n '1,30p' "${BASH_SOURCE[0]}" >&2; exit 0 ;;
    *)
      echo "restart_xsm: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$config_path" ]]; then
  if [[ -n "${XENOTA_REPO:-}" ]]; then
    config_path="$XENOTA_REPO/.xsm-local/swarm-backlog.yaml"
  elif [[ -f "$script_dir/resolve_repo_root.sh" ]]; then
    # Source resolver as a function provider; resolve under our own
    # caller-stack so a missing resolution surfaces as a clean error
    # instead of a sourced-script exit.
    # shellcheck source=/dev/null
    source "$script_dir/resolve_repo_root.sh"
    if repo_root="$(resolve_xenota_repo_root "$script_dir" 2>/dev/null)"; then
      config_path="$repo_root/.xsm-local/swarm-backlog.yaml"
    fi
  fi
fi

if [[ -z "$config_path" ]]; then
  echo "restart_xsm: could not resolve --config; pass it explicitly or set XENOTA_REPO" >&2
  exit 1
fi

resolved_config="$(cd "$(dirname "$config_path")" 2>/dev/null && pwd)/$(basename "$config_path")"
if [[ -z "$resolved_config" || ! -f "$resolved_config" ]]; then
  # Resolved path may not exist in dry-run / test contexts — fall back to
  # the literal user-supplied config_path so audit-log entries still record
  # what the caller asked us to act on.
  resolved_config="$config_path"
fi

repo_root_dir="$(dirname "$(dirname "$resolved_config")" 2>/dev/null || true)"
log_path="${RESTART_XSM_LOG:-$repo_root_dir/.xsm-local/restart_xsm.log}"

ps_cmd=("ps" "-axo" "pid=,command=")
if [[ -n "${RESTART_XSM_PS:-}" ]]; then
  # Test seam: split on whitespace so callers can inject a fixture command.
  read -r -a ps_cmd <<<"$RESTART_XSM_PS"
fi

kill_cmd=("kill")
if [[ -n "${RESTART_XSM_KILL:-}" ]]; then
  read -r -a kill_cmd <<<"$RESTART_XSM_KILL"
fi

# Find live xsm wrangle PIDs bound to this config. Match the literal
# ``xsm wrangle --config <path>`` substring so we don't kill an unrelated
# xsm monitor or a different daemon's wrangle.
collect_pids() {
  local needle="xsm wrangle --config $resolved_config"
  "${ps_cmd[@]}" \
    | awk -v needle="$needle" -v me="$$" '
        index($0, needle) > 0 {
          gsub(/^ +/, "", $0)
          split($0, parts, /[[:space:]]+/)
          if (parts[1] != me) { print parts[1] }
        }
      '
}

pids=()
while IFS= read -r pid; do
  [[ -n "$pid" ]] && pids+=("$pid")
done < <(collect_pids)

audit_log() {
  local outcome="$1"
  local detail="${2:-}"
  local ts
  ts="$(date -u +%FT%TZ)"
  local pids_csv
  if [[ ${#pids[@]} -eq 0 ]]; then
    pids_csv="none"
  else
    pids_csv="$(IFS=,; echo "${pids[*]}")"
  fi
  mkdir -p "$(dirname "$log_path")" 2>/dev/null || true
  printf '%s outcome=%s source=%s pr=%s sha=%s pids=%s detail=%s\n' \
    "$ts" "$outcome" "$source_label" \
    "${pr_ref:-none}" "${sha_ref:-none}" "$pids_csv" "${detail:-ok}" \
    >> "$log_path" 2>/dev/null || true
}

if [[ ${#pids[@]} -eq 0 ]]; then
  audit_log no_op "no live xsm wrangle process bound to $resolved_config"
  echo "restart_xsm: no live xsm wrangle bound to $resolved_config; nothing to restart" >&2
  exit 0
fi

if [[ "$dry_run" == "1" ]]; then
  audit_log dry_run "would SIGTERM pids ${pids[*]}"
  echo "restart_xsm: DRY RUN — would SIGTERM ${pids[*]}" >&2
  exit 0
fi

for pid in "${pids[@]}"; do
  "${kill_cmd[@]}" -TERM "$pid" 2>/dev/null || true
done

# Wait up to $wait_seconds for the targeted PIDs to exit. The relaunch
# wrapper's respawn happens AFTER xsm exits, so we only verify the SIGTERM
# took effect — not the new process.
deadline=$(( $(date +%s) + wait_seconds ))
while (( $(date +%s) < deadline )); do
  remaining=()
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && remaining+=("$pid")
  done < <(collect_pids)
  if [[ ${#remaining[@]} -eq 0 ]]; then
    audit_log restarted "SIGTERM acknowledged after $(( $(date +%s) - (deadline - wait_seconds) ))s"
    echo "restart_xsm: SIGTERM acknowledged for ${pids[*]}" >&2
    exit 0
  fi
  sleep 1
done

audit_log timeout "pids still alive after ${wait_seconds}s: ${remaining[*]:-${pids[*]}}"
echo "restart_xsm: pids still alive after ${wait_seconds}s — wrapper may be stuck or xsm did not honor SIGTERM" >&2
exit 1
