#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $label"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    exit 1
  fi
  echo "PASS: $label"
}

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
mkdir -p "$repo_root/xenon/packages/xsm/src/xsm" "$repo_root/.xsm-local"
git -C "$repo_root/xenon" init -q
git -C "$repo_root/xenon" config user.email "test@example.invalid"
git -C "$repo_root/xenon" config user.name "test"
echo "one" >"$repo_root/xenon/README.md"
git -C "$repo_root/xenon" add README.md
git -C "$repo_root/xenon" commit -q -m initial
before=$(git -C "$repo_root/xenon" rev-parse HEAD)

echo "two" >"$repo_root/xenon/README.md"
git -C "$repo_root/xenon" add README.md
git -C "$repo_root/xenon" commit -q -m docs
docs_after=$(git -C "$repo_root/xenon" rev-parse HEAD)

restart_calls="$tmpdir/restart-calls"
fake_restart="$tmpdir/fake-restart"
cat >"$fake_restart" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$restart_calls"
EOF
chmod +x "$fake_restart"

RESTART_XSM_BIN="$fake_restart" "$script_dir/restart_wrangle_if_xsm_changed.sh" "$before" "$docs_after" "$repo_root/xenon" >/tmp/restart-if-docs.out 2>&1
if [[ -f "$restart_calls" ]]; then
  docs_calls="$(wc -l <"$restart_calls" | tr -d '[:space:]')"
else
  docs_calls=0
fi
assert_eq "docs-change-does-not-restart" 0 "$docs_calls"

echo "xsm" >"$repo_root/xenon/packages/xsm/src/xsm/marker.py"
git -C "$repo_root/xenon" add packages/xsm/src/xsm/marker.py
git -C "$repo_root/xenon" commit -q -m xsm
xsm_after=$(git -C "$repo_root/xenon" rev-parse HEAD)

RESTART_XSM_BIN="$fake_restart" XSM_RESTART_REASON=test-post-merge \
  "$script_dir/restart_wrangle_if_xsm_changed.sh" "$docs_after" "$xsm_after" "$repo_root/xenon" >/tmp/restart-if-xsm.out 2>&1
assert_eq "xsm-change-restarts-once" 1 "$(wc -l <"$restart_calls" | tr -d '[:space:]')"
assert_contains "xsm-restart-reason" "--reason test-post-merge" "$(cat "$restart_calls")"
assert_contains "xsm-restart-sha" "--sha $xsm_after" "$(cat "$restart_calls")"

echo
echo "All restart_wrangle_if_xsm_changed tests passed."
