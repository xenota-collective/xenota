#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

cat >"$TMPDIR/bd" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    where)
        printf '{"prefix":"xc"}\n'
        ;;
    list)
        cat "$BD_LIST_JSON"
        ;;
    *)
        echo "unexpected bd command: $*" >&2
        exit 2
        ;;
esac
STUB
chmod +x "$TMPDIR/bd"

run_case() {
    local name="$1"
    local json="$2"
    local expected="$3"

    local json_file="$TMPDIR/$name.json"
    local output_file="$TMPDIR/$name.out"
    printf '%s\n' "$json" >"$json_file"

    set +e
    PATH="$TMPDIR:$PATH" BD_LIST_JSON="$json_file" \
        "$ROOT/scripts/check-beads-prefixes.sh" >"$output_file" 2>&1
    local status=$?
    set -e

    if [[ "$status" -ne "$expected" ]]; then
        echo "$name: expected exit $expected, got $status" >&2
        cat "$output_file" >&2
        exit 1
    fi
}

run_case "allows_exact_xsm_control_beads" '[
  {"id":"xsm-main-patrol","status":"open","issue_type":"task","title":"main patrol","labels":["xsm-control"]},
  {"id":"xsm-landing-queue","status":"in_progress","issue_type":"task","title":"landing queue","labels":["xsm-control"]}
]' 0

run_case "rejects_labeled_unlisted_xsm_bead" '[
  {"id":"xsm-extra-control","status":"open","issue_type":"task","title":"not allowlisted","labels":["xsm-control"]}
]' 1

run_case "rejects_non_xc_bead_with_xsm_control_label" '[
  {"id":"misc-control","status":"open","issue_type":"task","title":"wrong prefix","labels":["xsm-control"]}
]' 1

run_case "allows_mol_templates" '[
  {"id":"mol-example","status":"open","issue_type":"task","title":"template","is_template":true}
]' 0

echo "check-beads-prefixes regression tests passed"
