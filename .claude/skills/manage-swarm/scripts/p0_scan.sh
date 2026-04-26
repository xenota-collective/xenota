#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
default_rig_dir="$(cd "$script_dir/../../../.." && pwd)"
rig_dir="${1:-$default_rig_dir}"

cd "$rig_dir"
printf 'OPEN_P0\n'
bd list -p P0 -s open --flat --json
printf '\nIN_PROGRESS_P0\n'
bd list -p P0 -s in_progress --flat --json
