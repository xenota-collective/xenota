#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <bead-id>" >&2
  exit 2
fi

cd /Users/jv/gt/xenota/mayor/rig
exec bd show "$1"
