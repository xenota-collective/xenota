#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <worker-name>" >&2
  exit 2
fi

worker="$1"
repo="/Users/jv/gt/xenota/crew/${worker}"

if [[ ! -d "$repo" ]]; then
  echo "worker repo not found: $repo" >&2
  exit 1
fi

printf 'BRANCH\n'
git -C "$repo" branch --show-current
printf '\nSTATUS\n'
git -C "$repo" status --short
printf '\nHOOK\n'
gt hook show "xenota/crew/${worker}"
