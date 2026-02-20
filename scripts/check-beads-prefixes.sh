#!/usr/bin/env bash
set -euo pipefail

if ! command -v bd >/dev/null 2>&1; then
    echo "bd not found; skipping beads prefix check"
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required for beads prefix check"
    exit 1
fi

where_json="$(bd where --json)"
prefix="$(jq -r '.prefix' <<<"$where_json")"

violations="$(
    bd list --limit 0 --json | jq -r --arg prefix "$prefix" '
        .[]
        | select((.status == "open" or .status == "in_progress" or .status == "hooked"))
        | select((.id | startswith($prefix + "-")) | not)
        # mol-* templates are proto/formula definitions and are intentionally shared.
        | select((((.is_template // false) == true) and (.id | startswith("mol-"))) | not)
        | [.id, .status, .issue_type, .title] | @tsv
    '
)"

if [[ -n "$violations" ]]; then
    echo "beads prefix guard failed: found active non-${prefix}- issues"
    echo "$violations" | sed 's/^/  - /'
    exit 1
fi

echo "beads prefix guard passed: active issues use ${prefix}- prefix"
