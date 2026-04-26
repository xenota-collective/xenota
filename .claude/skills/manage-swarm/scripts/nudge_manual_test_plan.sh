#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <worker-name> <epic>" >&2
  exit 2
fi

worker="$1"
epic="$2"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "$script_dir/send_worker_message.sh" "$worker" "Write a detailed manual testing plan as comments on ${epic} with setup, commands, pass/fail, and deferred integration gaps."
