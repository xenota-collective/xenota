#!/usr/bin/env bash
set -euo pipefail

# Unit tests for xsm_relaunch_loop (xc-twaa6).
#
# The tests build fake ``xsm_bin`` scripts that exit with a controlled
# pattern of return codes and then drive the loop directly so we can
# assert on relaunch counts, exit codes, and stdout messages without
# actually running the real xsm.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./xsm_relaunch_loop.sh
source "$script_dir/xsm_relaunch_loop.sh"

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

make_fake_xsm() {
  local label="$1"
  local script_body="$2"
  local target="$tmpdir/xsm_$label"
  cat >"$target" <<EOF
#!/usr/bin/env bash
$script_body
EOF
  chmod +x "$target"
  printf '%s' "$target"
}

# Case 1: graceful exit (rc=0), capped after N restarts
counter_file="$tmpdir/case1_count"
echo 0 >"$counter_file"
fake_graceful=$(make_fake_xsm "graceful" "
count=\$(cat \"$counter_file\")
count=\$((count + 1))
echo \"\$count\" >\"$counter_file\"
exit 0
")
config="$tmpdir/cfg"
echo "{}" >"$config"

# Backoff = 0 to keep the test fast. Cap = 3 so loop stops at 4 iterations.
output=$(xsm_relaunch_loop "$fake_graceful" "$config" 0 3 2>&1)
final_rc=$?
final_count=$(cat "$counter_file")
assert_eq "graceful-loop-rc" 0 "$final_rc"
assert_eq "graceful-loop-iterations" 4 "$final_count"
assert_contains "graceful-loop-cap-message" "restart cap reached" "$output"
assert_contains "graceful-loop-relaunch-message" "graceful" "$output"

# Case 2: non-graceful exit (rc=2) on first invocation breaks immediately
counter_file2="$tmpdir/case2_count"
echo 0 >"$counter_file2"
fake_failure=$(make_fake_xsm "failure" "
count=\$(cat \"$counter_file2\")
count=\$((count + 1))
echo \"\$count\" >\"$counter_file2\"
exit 2
")
output=$(xsm_relaunch_loop "$fake_failure" "$config" 0 5 2>&1) || final_rc=$?
final_count=$(cat "$counter_file2")
assert_eq "failure-loop-rc" 2 "$final_rc"
assert_eq "failure-loop-iterations" 1 "$final_count"
assert_contains "failure-loop-message" "non-graceful" "$output"
assert_contains "failure-loop-not-auto-restart" "not auto-restarting" "$output"

# Case 3: graceful then failure — graceful relaunches, failure breaks
counter_file3="$tmpdir/case3_count"
echo 0 >"$counter_file3"
fake_mixed=$(make_fake_xsm "mixed" "
count=\$(cat \"$counter_file3\")
count=\$((count + 1))
echo \"\$count\" >\"$counter_file3\"
if [ \"\$count\" -lt 3 ]; then
  exit 0
fi
exit 4
")
output=$(xsm_relaunch_loop "$fake_mixed" "$config" 0 10 2>&1) || final_rc=$?
final_count=$(cat "$counter_file3")
assert_eq "mixed-loop-rc" 4 "$final_rc"
assert_eq "mixed-loop-iterations" 3 "$final_count"
assert_contains "mixed-loop-graceful-relaunch" "rc=0 (graceful)" "$output"
assert_contains "mixed-loop-final-failure" "non-graceful" "$output"

# Case 4: explicit per-call cap respected (cap=1 means 2nd graceful exit
# stops the loop)
counter_file4="$tmpdir/case4_count"
echo 0 >"$counter_file4"
fake_count_only=$(make_fake_xsm "count_only" "
count=\$(cat \"$counter_file4\")
count=\$((count + 1))
echo \"\$count\" >\"$counter_file4\"
exit 0
")
output=$(xsm_relaunch_loop "$fake_count_only" "$config" 0 1 2>&1)
final_rc=$?
final_count=$(cat "$counter_file4")
assert_eq "cap-1-loop-rc" 0 "$final_rc"
# Cap is "restarts > cap" so cap=1 lets exactly 2 iterations through (1
# initial + 1 relaunch) before stopping.
assert_eq "cap-1-loop-iterations" 2 "$final_count"
assert_contains "cap-1-loop-cap-message" "restart cap reached" "$output"

# Case 5: EX_TEMPFAIL (rc=75) treated as graceful
counter_file5="$tmpdir/case5_count"
echo 0 >"$counter_file5"
fake_tempfail=$(make_fake_xsm "tempfail" "
count=\$(cat \"$counter_file5\")
count=\$((count + 1))
echo \"\$count\" >\"$counter_file5\"
exit 75
")
output=$(xsm_relaunch_loop "$fake_tempfail" "$config" 0 1 2>&1)
final_rc=$?
final_count=$(cat "$counter_file5")
assert_eq "tempfail-loop-rc" 0 "$final_rc"
assert_eq "tempfail-loop-iterations" 2 "$final_count"
assert_contains "tempfail-loop-graceful-relaunch" "rc=75 (graceful)" "$output"

echo
echo "All xsm_relaunch_loop tests passed."
