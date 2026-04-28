#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/resolve_repo_root.sh"
if ! default_rig_dir="$(resolve_xenota_repo_root "$script_dir")"; then
  echo "p0_scan: could not locate live xenota repo root with .xsm-local/swarm-backlog.yaml from $script_dir; set XENOTA_REPO to override or pass an explicit rig dir as \$1" >&2
  exit 1
fi
rig_dir="${1:-$default_rig_dir}"

cd "$rig_dir"
printf 'OPEN_P0\n'
bd list -p P0 -s open --flat --json
printf '\nIN_PROGRESS_P0\n'
bd list -p P0 -s in_progress --flat --json
