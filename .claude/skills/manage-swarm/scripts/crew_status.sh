#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <worker-name>" >&2
  exit 2
fi

worker="$1"

if ! command -v workmux >/dev/null 2>&1; then
  echo "workmux is required to resolve worker repo paths" >&2
  exit 1
fi

repo="$(workmux path "$worker" 2>/dev/null)"

if [[ -z "$repo" || ! -d "$repo" ]]; then
  echo "worker repo not found via workmux for: $worker" >&2
  exit 1
fi

printf 'BRANCH\n'
git -C "$repo" branch --show-current
printf '\nSTATUS\n'
git -C "$repo" status --short
