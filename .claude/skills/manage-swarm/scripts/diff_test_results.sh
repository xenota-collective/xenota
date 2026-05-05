#!/usr/bin/env bash
# diff_test_results.sh — capture-and-compare pytest results across a merge.
#
# Usage:
#   diff_test_results.sh snapshot <label>            # run + save baseline
#   diff_test_results.sh compare  <baseline-label>   # run, diff, exit non-zero on regression
#
# Snapshots and diffs are written to .xsm-local/test-snapshots/<label>.txt
# (one line per "FAILED <node-id>"). Compare exits 1 if any test that was
# passing in the baseline is failing in the current run. Calling
# regressions "pre-existing" without evidence is exactly how the failed
# 2026-05-05 session shipped six PRs on top of an actually-broken suite.

set -euo pipefail

REPO="${REPO:-/Users/jv/projects/xenota}"
SNAP_DIR="$REPO/.xsm-local/test-snapshots"
mkdir -p "$SNAP_DIR"

cmd="${1:-}"; label="${2:-}"
if [[ -z "$cmd" || -z "$label" ]]; then
  sed -n '2,15p' "$0"; exit 64
fi

run_pytest() {
  cd "$REPO/xenon/packages/xsm"
  uv run pytest --tb=no -q 2>&1
}

case "$cmd" in
  snapshot)
    out="$SNAP_DIR/$label.txt"
    echo "diff_test_results: snapshotting -> $out" >&2
    run_pytest | grep -E "^(FAILED|ERROR)" | sort -u > "$out" || true
    summary=$(run_pytest | grep -E "^[0-9]+ (passed|failed)" | tail -1)
    echo "  baseline: $(wc -l < "$out") failures; $summary" >&2
    exit 0
    ;;
  compare)
    baseline="$SNAP_DIR/$label.txt"
    [[ -f "$baseline" ]] || { echo "diff_test_results: no baseline at $baseline" >&2; exit 2; }
    current="$SNAP_DIR/_current.txt"
    run_pytest | grep -E "^(FAILED|ERROR)" | sort -u > "$current" || true
    new=$(comm -13 "$baseline" "$current")
    fixed=$(comm -23 "$baseline" "$current")
    [[ -n "$fixed"  ]] && { echo "fixed since baseline:"; echo "$fixed";  }
    [[ -n "$new"    ]] && { echo "REGRESSED since baseline:"; echo "$new"; }
    if [[ -n "$new" ]]; then
      echo "diff_test_results: REGRESSION — at least one test newly fails. This is YOUR breakage until proven otherwise. Do not declare landing successful." >&2
      exit 1
    fi
    echo "diff_test_results: OK — no new failures vs baseline '$label'."
    exit 0
    ;;
  *)
    echo "unknown command: $cmd" >&2; exit 64 ;;
esac
