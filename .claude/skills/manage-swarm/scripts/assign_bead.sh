#!/usr/bin/env bash
# Assign a bead to a crew worker, atomically releasing any prior in_progress
# beads on that worker. Enforces the single-active-bead invariant from
# xc-9l5su: ``bd list --assignee <worker> --status in_progress | wc -l``
# must return 0 or 1 after this script exits successfully.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <bead-id> <worker-name>" >&2
  exit 2
fi

bead_id="$1"
worker="$2"
assignee="xenota/crew/${worker}"

# Resolve a working directory where bd can find its database. Tests override
# ASSIGN_BEAD_RIG to point at a fixture; otherwise the script's own repo
# root is used so bd's auto-discovery walks up to .beads/.
if [[ -n "${ASSIGN_BEAD_RIG:-}" ]]; then
  cd "$ASSIGN_BEAD_RIG"
else
  cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && git rev-parse --show-toplevel)"
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "assign_bead: jq is required to enforce single-active-bead invariant" >&2
  exit 2
fi

timestamp="$(date -u +%FT%TZ)"

# Release any prior in_progress beads on this worker so the new assignment
# is the sole live one. Live bd has both `xenota/crew/<worker>` and legacy
# plain `<worker>` rows; both spellings must be enumerated or the other
# half stays stuck in_progress and the invariant never converges. Errors
# are surfaced (no `|| true`) because a missing state read would silently
# violate the single-active-bead invariant.
prev_ids="$(
  {
    bd list --assignee "$assignee" --status in_progress --json \
      | jq -r '.[].id // empty'
    bd list --assignee "$worker" --status in_progress --json \
      | jq -r '.[].id // empty'
  } | awk 'NF && !seen[$0]++'
)"

if [[ -n "${prev_ids:-}" ]]; then
  while IFS= read -r prev; do
    [[ -z "$prev" ]] && continue
    if [[ "$prev" == "$bead_id" ]]; then
      continue
    fi
    bd update "$prev" -s blocked >/dev/null
    bd comment "$prev" \
      "auto-released: $assignee reassigned to $bead_id at $timestamp" \
      >/dev/null
  done <<<"$prev_ids"
fi

exec bd update "$bead_id" -s in_progress -a "$assignee"
