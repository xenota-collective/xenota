#!/usr/bin/env bash
set -euo pipefail

rig_dir="${1:-/Users/jv/gt/xenota/mayor/rig}"

cd "$rig_dir"
printf 'OPEN_P0\n'
bd list -p P0 -s open --flat --json
printf '\nIN_PROGRESS_P0\n'
bd list -p P0 -s in_progress --flat --json
