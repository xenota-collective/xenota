#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <worker-name|tmux-target> <message>" >&2
  exit 2
fi

worker="$1"
shift
message="$*"

repo_root="${XENOTA_REPO:-/Users/jv/projects/xenota}"
xsm_bin="${XSM_BIN:-$repo_root/xenon/packages/xsm/.venv/bin/xsm}"
xsm_config="${XSM_CONFIG:-$repo_root/.xsm-local/swarm-backlog.yaml}"

worker_id="$worker"
if [[ "$worker_id" == *:* ]]; then
  worker_id="${worker_id#*:}"
  worker_id="${worker_id%.*}"
fi

if [[ ! -x "$xsm_bin" ]]; then
  echo "send_worker_message: missing checked-out xsm runtime: $xsm_bin" >&2
  exit 1
fi

output="$(
  "$xsm_bin" message \
    --config "$xsm_config" \
    --worker "$worker_id" \
    --payload "$message" \
    --json
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
