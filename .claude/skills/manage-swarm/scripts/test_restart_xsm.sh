#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

assert_contains() {
  local label="$1"
  local needle="$2"
  local haystack="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "FAIL: $label"
    echo "  needle:   $needle"
    echo "  haystack: $haystack"
    exit 1
  fi
  echo "PASS: $label"
}

repo_root="$tmpdir/repo"
mkdir -p "$repo_root/.xsm-local" "$repo_root/xenon/packages/xsm/src/xsm"
git -C "$repo_root/xenon" init -q
git -C "$repo_root/xenon" config user.email "test@example.invalid"
git -C "$repo_root/xenon" config user.name "test"
echo "x" >"$repo_root/xenon/packages/xsm/src/xsm/marker.py"
git -C "$repo_root/xenon" add packages/xsm/src/xsm/marker.py
git -C "$repo_root/xenon" commit -q -m initial

config="$repo_root/.xsm-local/swarm-backlog.yaml"
echo "{}" >"$config"
audit="$tmpdir/restarts.jsonl"
ps_output=$'  123 /tmp/xsm wrangle --config '"$config"$' --json\n456 unrelated process'

output=$(XSM_RESTART_AUDIT_LOG="$audit" XSM_RESTART_PS_OUTPUT="$ps_output" \
  "$script_dir/restart_xsm.sh" --repo-root "$repo_root" --config "$config" --reason test --pr xenon#1 --sha abc123 --dry-run 2>&1)
assert_contains "dry-run-output" "dry-run would SIGTERM xsm wrangle pid=123" "$output"
assert_contains "signalled-output" "SIGTERM sent to xsm wrangle pid(s): 123" "$output"
assert_contains "audit-tool" '"tool":"restart_xsm"' "$(cat "$audit")"
assert_contains "audit-pr" '"pr_ref":"xenon#1"' "$(cat "$audit")"
assert_contains "audit-status" '"status":"signalled"' "$(cat "$audit")"

audit2="$tmpdir/no-running.jsonl"
output=$(XSM_RESTART_AUDIT_LOG="$audit2" XSM_RESTART_PS_OUTPUT="456 unrelated process" \
  "$script_dir/restart_xsm.sh" --repo-root "$repo_root" --config "$config" --reason test --dry-run 2>&1)
assert_contains "no-running-output" "no running xsm wrangle process found" "$output"
assert_contains "no-running-audit" '"status":"no_running_wrangle"' "$(cat "$audit2")"

audit3="$tmpdir/empty-pr.jsonl"
output=$(XSM_RESTART_AUDIT_LOG="$audit3" XSM_RESTART_PS_OUTPUT="456 unrelated process" \
  "$script_dir/restart_xsm.sh" --repo-root "$repo_root" --config "$config" --reason test --pr "" --sha abc123 --dry-run 2>&1)
assert_contains "empty-pr-output" "no running xsm wrangle process found" "$output"
assert_contains "empty-pr-audit" '"pr_ref":""' "$(cat "$audit3")"

echo
echo "All restart_xsm tests passed."
