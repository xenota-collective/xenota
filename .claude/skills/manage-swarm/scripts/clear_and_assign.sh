#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"
source "$script_dir/resolve_repo_root.sh"

if ! repo_root="$(resolve_xenota_repo_root "$script_dir")"; then
  echo "clear_and_assign: could not locate live xenota repo root with .xsm-local/swarm-backlog.yaml from $script_dir; set XENOTA_REPO to override" >&2
  exit 1
fi
export XENOTA_REPO="$repo_root"

respawn=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --respawn)
      respawn=1
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "clear_and_assign: unknown option $1" >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -lt 2 ]]; then
  echo "usage: $0 [--respawn] <worker-name|tmux-target> <instruction>" >&2
  exit 2
fi

worker="$1"
shift
instruction="$*"

target="$(resolve_worker_target "$worker")"

if [[ "$respawn" == "1" ]]; then
  "$script_dir/send_worker_message.sh" --respawn --interrupt --kind reset "$worker" "$instruction"
  exit $?
fi

if ! "$script_dir/send_worker_message.sh" --interrupt --kind reset "$worker" "/clear"; then
  echo "clear_and_assign: centralized /clear delivery failed for $worker" >&2
  exit 1
fi

if ! tmux_wait_for_ready_prompt "$target" 30; then
  echo "clear_and_assign: /clear did not settle cleanly on $target" >&2
  tmux_recent_pane_text "$target" >&2
  exit 1
fi

"$script_dir/send_worker_message.sh" "$worker" "$instruction"
