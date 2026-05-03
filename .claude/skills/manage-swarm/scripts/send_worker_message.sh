#!/usr/bin/env bash
set -euo pipefail

interrupt=0
respawn=0
kind="instruction"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interrupt)
      interrupt=1
      shift
      ;;
    --respawn)
      respawn=1
      shift
      ;;
    --kind)
      if [[ $# -lt 2 ]]; then
        echo "send_worker_message: --kind requires a value" >&2
        exit 2
      fi
      kind="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "send_worker_message: unknown option $1" >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -lt 2 ]]; then
  echo "usage: $0 [--interrupt] [--respawn] [--kind <kind>] <worker-name|tmux-target> <message>" >&2
  exit 2
fi

worker="$1"
shift
message="$*"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/resolve_repo_root.sh"

if ! repo_root="$(resolve_xenota_repo_root "$script_dir")"; then
  echo "send_worker_message: could not locate live xenota repo root with .xsm-local/swarm-backlog.yaml from $script_dir; set XENOTA_REPO to override" >&2
  exit 1
fi
xsm_bin="${XSM_BIN:-$repo_root/xenon/packages/xsm/.venv/bin/xsm}"
xsm_config="${XSM_CONFIG:-$repo_root/.xsm-local/swarm-backlog.yaml}"

if [[ "$xsm_bin" != /* ]]; then
  xsm_bin="$PWD/$xsm_bin"
fi
if [[ "$xsm_config" != /* ]]; then
  xsm_config="$PWD/$xsm_config"
fi

worker_id="$worker"
if [[ "$worker_id" == *:* ]]; then
  worker_id="${worker_id#*:}"
  worker_id="${worker_id%.*}"
fi

if [[ ! -x "$xsm_bin" ]]; then
  echo "send_worker_message: missing checked-out xsm runtime: $xsm_bin" >&2
  exit 1
fi

args=(
  message
  --config "$xsm_config"
  --worker "$worker_id"
  --payload "$message"
  --kind "$kind"
  --json
)
if [[ "$interrupt" == "1" ]]; then
  args+=(--interrupt)
fi
if [[ "$respawn" == "1" ]]; then
  args+=(--respawn)
fi

# xc-r6r8: anchor xsm's cwd to the xenota workspace root so the workmux
# driver's `workmux list --json` lookup returns top-level worktrees (e.g.
# worker-claude-1) instead of submodule-scoped results. Without this, a
# helper invoked from inside the xenon submodule fails closed with
# "No agent running in worktree '<handle>'" against an active worker pane.
output="$(
  cd "$repo_root" && XENOTA_REPO="$repo_root" "$xsm_bin" "${args[@]}"
)"

if command -v jq >/dev/null 2>&1; then
  if ! jq -e '.ok == true' >/dev/null <<<"$output"; then
    echo "$output" >&2
    exit 1
  fi
elif ! grep -q '"ok":[[:space:]]*true' <<<"$output"; then
  echo "$output" >&2
  exit 1
fi

printf '%s\n' "$output"
