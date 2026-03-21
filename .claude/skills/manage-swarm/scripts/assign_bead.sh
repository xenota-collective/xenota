#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <bead-id> <worker-name>" >&2
  exit 2
fi

cd /Users/jv/gt/xenota/mayor/rig
exec bd update "$1" -a "xenota/crew/$2"
