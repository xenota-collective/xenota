#!/usr/bin/env bash
# Regression test for assign_bead.sh:
# 1. Releases prior in_progress beads on the same worker.
# 2. Skips the new target bead if it is already in the worker's in_progress list.
# 3. Falls through to ``bd update <bead> -s in_progress -a <assignee>``.
# 4. Releases stale rows under both `xenota/crew/<worker>` and legacy `<worker>`.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Stub bd binary that records every invocation and returns assignee-keyed
# scripted output. BD_LIST_<key> points at a JSON file for that assignee;
# BD_LIST_FAIL=1 forces every `bd list` to exit non-zero so we can prove the
# script surfaces those errors instead of swallowing them.
cat > "$tmp/bd" <<'BD'
#!/usr/bin/env bash
log_path="${BD_LOG:?missing}"
case "${1:-}" in
  list)
    if [[ "${BD_LIST_FAIL:-0}" == "1" ]]; then
      echo "bd list: simulated failure" >&2
      exit 9
    fi
    assignee=""
    for ((i=2; i<=$#; i++)); do
      if [[ "${!i}" == "--assignee" ]]; then
        next=$((i+1))
        assignee="${!next}"
        break
      fi
    done
    # Sanitize the assignee into a shell-safe variable name suffix.
    key="$(printf '%s' "$assignee" | tr -c 'A-Za-z0-9' '_')"
    var="BD_LIST_${key}"
    list_path="${!var:-}"
    if [[ -n "$list_path" && -f "$list_path" ]]; then
      cat "$list_path"
    else
      echo "[]"
    fi
    exit 0
    ;;
  *)
    printf '%s\n' "$*" >>"$log_path"
    exit 0
    ;;
esac
BD
chmod +x "$tmp/bd"

# Mixed-spelling fixture: half the worker's stale rows live under the
# canonical xenota/crew/<worker> assignee, half under the legacy plain
# <worker> assignee. The helper must release both sets, dedup the overlap
# (xc-keep listed under both spellings), and assign the new bead exactly
# once.
cat > "$tmp/list_prefixed.json" <<'JSON'
[
  {"id":"xc-old1","status":"in_progress"},
  {"id":"xc-keep","status":"in_progress"}
]
JSON
cat > "$tmp/list_legacy.json" <<'JSON'
[
  {"id":"xc-old2","status":"in_progress"},
  {"id":"xc-keep","status":"in_progress"}
]
JSON

export PATH="$tmp:$PATH"
export BD_LOG="$tmp/bd.log"
# Stub bd uses these env vars to pick the right list-fixture per assignee.
export BD_LIST_xenota_crew_worker_claude_1="$tmp/list_prefixed.json"
export BD_LIST_worker_claude_1="$tmp/list_legacy.json"
# ASSIGN_BEAD_RIG redirects the script's cd target without rewriting the file.
export ASSIGN_BEAD_RIG="$tmp"
: >"$BD_LOG"

"$script_dir/assign_bead.sh" xc-keep worker-claude-1 >/dev/null

mapfile -t lines < "$BD_LOG"
if [[ ${#lines[@]} -ne 5 ]]; then
  printf 'expected 5 bd invocations, got %d:\n' "${#lines[@]}" >&2
  printf '%s\n' "${lines[@]}" >&2
  exit 1
fi

# Two updates + two comments (one per stale bead from each spelling), then
# the new assignment. The duplicated xc-keep row across both spellings must
# be deduped so it's not released twice or counted as stale.
expected_prefixes=(
  "update xc-old1 -s blocked"
  "comment xc-old1"
  "update xc-old2 -s blocked"
  "comment xc-old2"
  "update xc-keep -s in_progress -a xenota/crew/worker-claude-1"
)
for i in "${!expected_prefixes[@]}"; do
  if [[ "${lines[$i]}" != "${expected_prefixes[$i]}"* ]]; then
    echo "line $((i+1)) mismatch:" >&2
    echo "  expected prefix: ${expected_prefixes[$i]}" >&2
    echo "  actual:          ${lines[$i]}" >&2
    exit 1
  fi
done

# The xc-keep bead must NOT be released even though it appears in both
# spellings' in_progress lists (the new target survives the atomic transfer).
for line in "${lines[@]}"; do
  if [[ "$line" == "update xc-keep -s blocked"* ]]; then
    echo "assign_bead released the new target bead xc-keep" >&2
    exit 1
  fi
done

# Failure case: when `bd list` exits non-zero, the script must NOT silently
# proceed to assign — the previous `|| true` guard would have swallowed it.
: >"$BD_LOG"
BD_LIST_FAIL=1 "$script_dir/assign_bead.sh" xc-keep worker-claude-1 >/dev/null 2>"$tmp/err.log" \
  && {
    echo "assign_bead masked a bd list failure" >&2
    exit 1
  } || true
if [[ -s "$BD_LOG" ]]; then
  echo "assign_bead issued bd writes after bd list failure:" >&2
  cat "$BD_LOG" >&2
  exit 1
fi

echo "test_assign_bead.sh: PASS"
