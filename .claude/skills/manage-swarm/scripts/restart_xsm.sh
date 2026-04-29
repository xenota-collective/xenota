#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/resolve_repo_root.sh"

reason="manual"
pr_ref=""
sha_ref=""
repo_root="${XENOTA_REPO:-}"
config_path=""
dry_run="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reason)
      reason="${2:?restart_xsm: --reason requires a value}"
      shift 2
      ;;
    --pr|--pr-ref)
      pr_ref="${2:?restart_xsm: --pr requires a value}"
      shift 2
      ;;
    --sha|--sha-ref)
      sha_ref="${2:?restart_xsm: --sha requires a value}"
      shift 2
      ;;
    --repo-root)
      repo_root="${2:?restart_xsm: --repo-root requires a value}"
      shift 2
      ;;
    --config)
      config_path="${2:?restart_xsm: --config requires a value}"
      shift 2
      ;;
    --dry-run)
      dry_run="1"
      shift
      ;;
    *)
      echo "usage: $0 [--reason text] [--pr ref] [--sha sha] [--repo-root path] [--config path] [--dry-run]" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$repo_root" ]]; then
  if ! repo_root="$(resolve_xenota_repo_root "$script_dir")"; then
    echo "restart_xsm: could not locate xenota repo root; set XENOTA_REPO or pass --repo-root" >&2
    exit 1
  fi
fi
config_path="${config_path:-$repo_root/.xsm-local/swarm-backlog.yaml}"
resolved_config_path="$config_path"
if [[ -f "$config_path" ]]; then
  resolved_config_path="$(cd "$(dirname "$config_path")" && pwd)/$(basename "$config_path")"
fi

audit_log="${XSM_RESTART_AUDIT_LOG:-$repo_root/.xsm-local/log/xsm-restarts.jsonl}"
mkdir -p "$(dirname "$audit_log")"

xsm_packages_sha=""
if [[ -d "$repo_root/xenon/.git" || -f "$repo_root/xenon/.git" ]]; then
  xsm_packages_sha="$(git -C "$repo_root/xenon" log -1 --format=%H -- packages/xsm/ 2>/dev/null || true)"
fi

ps_lines="${XSM_RESTART_PS_OUTPUT:-}"
if [[ -z "$ps_lines" ]]; then
  ps_lines="$(ps -axo pid=,command=)"
fi

pids=()
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  if [[ "$line" == *" wrangle --config $resolved_config_path"* || "$line" == *" wrangle --config $config_path"* ]]; then
    line="${line#"${line%%[![:space:]]*}"}"
    pid="${line%%[[:space:]]*}"
    pid="${pid//[!0-9]/}"
    [[ -n "$pid" && "$pid" != "$$" ]] && pids+=("$pid")
  fi
done <<<"$ps_lines"

status="signalled"
if (( ${#pids[@]} == 0 )); then
  status="no_running_wrangle"
else
  for pid in "${pids[@]}"; do
    if [[ "$dry_run" == "1" ]]; then
      echo "restart_xsm: dry-run would SIGTERM xsm wrangle pid=$pid"
    else
      kill -TERM "$pid" 2>/dev/null || true
    fi
  done
fi

jq -cn \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg trigger "restart_xsm_signal" \
  --arg reason "$reason" \
  --arg pr_ref "$pr_ref" \
  --arg sha_ref "$sha_ref" \
  --arg config_path "$resolved_config_path" \
  --arg status "$status" \
  --arg xsm_packages_sha "$xsm_packages_sha" \
  --argjson pids "$(printf '%s\n' "${pids[@]:-}" | jq -R 'select(length>0) | tonumber' | jq -s '.')" \
  '{timestamp:$ts,tool:"restart_xsm",trigger:$trigger,reason:$reason,pr_ref:$pr_ref,sha_ref:$sha_ref,config_path:$config_path,status:$status,pids:$pids,packages_xsm_sha:$xsm_packages_sha}' \
  >>"$audit_log"

if [[ "$status" == "no_running_wrangle" ]]; then
  echo "restart_xsm: no running xsm wrangle process found for $resolved_config_path; audit logged"
else
  echo "restart_xsm: SIGTERM sent to xsm wrangle pid(s): ${pids[*]}; relaunch loop should respawn; audit logged"
fi
