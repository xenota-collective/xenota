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
export XSM_RELAUNCH_DISABLE_PATH_POLL=1
loop_died_log="$tmpdir/loop-died.jsonl"
export XSM_LOOP_DIED_LOG="$loop_died_log"

# Backoff = 0 to keep the test fast. Cap = 3 so loop stops at 4 iterations.
output=$(xsm_relaunch_loop "$fake_graceful" "$config" 0 3 2>&1)
final_rc=$?
final_count=$(cat "$counter_file")
assert_eq "graceful-loop-rc" 0 "$final_rc"
assert_eq "graceful-loop-iterations" 4 "$final_count"
assert_contains "graceful-loop-cap-message" "restart cap reached" "$output"
assert_contains "graceful-loop-relaunch-message" "graceful" "$output"
assert_contains "graceful-loop-died-marker" '"reason":"restart_cap_reached"' "$(cat "$loop_died_log")"

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
assert_contains "failure-loop-died-marker" '"reason":"non_graceful_exit"' "$(cat "$loop_died_log")"
assert_contains "failure-loop-died-rc" '"last_rc":2' "$(cat "$loop_died_log")"

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

# Case 4b: loop-died marker carries the latest wrangle run id and tracker age.
repo_root4b="$tmpdir/repo4b"
mkdir -p "$repo_root4b/.xsm-local/log/swarm-backlog/wrangle-runs/20260504T010000-old"
mkdir -p "$repo_root4b/.xsm-local/log/swarm-backlog/wrangle-runs/20260504T020000-new"
config4b="$repo_root4b/.xsm-local/swarm-backlog.yaml"
echo "{}" >"$config4b"
counter_file4b="$tmpdir/case4b_count"
echo 0 >"$counter_file4b"
fake_cap_marker=$(make_fake_xsm "cap_marker" "
count=\$(cat \"$counter_file4b\")
count=\$((count + 1))
echo \"\$count\" >\"$counter_file4b\"
exit 0
")
loop_died_log4b="$tmpdir/loop-died-4b.jsonl"
output=$(XSM_LOOP_DIED_LOG="$loop_died_log4b" xsm_relaunch_loop "$fake_cap_marker" "$config4b" 0 0 "$repo_root4b" 2>&1)
assert_contains "cap-marker-latest-run" '"last_run_id":"20260504T020000-new"' "$(cat "$loop_died_log4b")"
assert_contains "cap-marker-tracker-age" '"tracker_file_age_secs":' "$(cat "$loop_died_log4b")"

# Case 4c: default cap is 50 when no explicit cap/env override is passed.
counter_file4c="$tmpdir/case4c_count"
echo 0 >"$counter_file4c"
fake_default_cap=$(make_fake_xsm "default_cap" "
count=\$(cat \"$counter_file4c\")
count=\$((count + 1))
echo \"\$count\" >\"$counter_file4c\"
exit 0
")
output=$(xsm_relaunch_loop "$fake_default_cap" "$config" 0 2>&1)
final_rc=$?
final_count=$(cat "$counter_file4c")
assert_eq "default-cap-loop-rc" 0 "$final_rc"
assert_eq "default-cap-loop-iterations" 51 "$final_count"
assert_contains "default-cap-message" "restart cap reached" "$output"

# Case 4d: env override controls the default cap when no explicit cap is passed.
counter_file4d="$tmpdir/case4d_count"
echo 0 >"$counter_file4d"
fake_env_cap=$(make_fake_xsm "env_cap" "
count=\$(cat \"$counter_file4d\")
count=\$((count + 1))
echo \"\$count\" >\"$counter_file4d\"
exit 0
")
output=$(XSM_RELAUNCH_RESTART_CAP=2 xsm_relaunch_loop "$fake_env_cap" "$config" 0 2>&1)
final_rc=$?
final_count=$(cat "$counter_file4d")
assert_eq "env-cap-loop-rc" 0 "$final_rc"
assert_eq "env-cap-loop-iterations" 3 "$final_count"
assert_contains "env-cap-message" "restart cap reached" "$output"

# Case 4e: code-change exits inside the carve-out window do not consume cap.
repo_root4e="$tmpdir/repo4e"
mkdir -p "$repo_root4e/xenon/packages/xsm/src/xsm" "$repo_root4e/.xsm-local"
git -C "$repo_root4e/xenon" init -q
git -C "$repo_root4e/xenon" config user.email "test@example.invalid"
git -C "$repo_root4e/xenon" config user.name "test"
echo "0" >"$repo_root4e/xenon/packages/xsm/src/xsm/marker.py"
git -C "$repo_root4e/xenon" add packages/xsm/src/xsm/marker.py
git -C "$repo_root4e/xenon" commit -q -m initial

config4e="$repo_root4e/.xsm-local/swarm-backlog.yaml"
echo "{}" >"$config4e"
counter_file4e="$tmpdir/case4e_count"
echo 0 >"$counter_file4e"
fake_code_change_cascade=$(make_fake_xsm "code_change_cascade" "
count=\$(cat \"$counter_file4e\")
count=\$((count + 1))
echo \"\$count\" >\"$counter_file4e\"
if [ \"\$count\" -le 30 ]; then
  echo \"\$count\" >\"$repo_root4e/xenon/packages/xsm/src/xsm/marker.py\"
  git -C \"$repo_root4e/xenon\" add packages/xsm/src/xsm/marker.py
  git -C \"$repo_root4e/xenon\" commit -q -m \"change-\$count\"
  exit 75
fi
exit 5
")
final_rc=0
output=$(XSM_RELAUNCH_RESTART_CAP=3 XSM_RELAUNCH_CODE_CHANGE_WINDOW_SECS=60 xsm_relaunch_loop "$fake_code_change_cascade" "$config4e" 0 "" "$repo_root4e" 2>&1) || final_rc=$?
final_count=$(cat "$counter_file4e")
assert_eq "code-change-cascade-final-rc" 5 "$final_rc"
assert_eq "code-change-cascade-iterations" 31 "$final_count"
assert_contains "code-change-cascade-carveout" "code-change carve-out" "$output"

unset XSM_RELAUNCH_DISABLE_PATH_POLL

# Case 5: packages/xsm path change while xsm is running terminates the child
# and relaunches without touching the live daemon.
repo_root="$tmpdir/repo"
mkdir -p "$repo_root/xenon/packages/xsm/src/xsm" "$repo_root/.xsm-local"
git -C "$repo_root/xenon" init -q
git -C "$repo_root/xenon" config user.email "test@example.invalid"
git -C "$repo_root/xenon" config user.name "test"
echo "one" >"$repo_root/xenon/packages/xsm/src/xsm/marker.py"
git -C "$repo_root/xenon" add packages/xsm/src/xsm/marker.py
git -C "$repo_root/xenon" commit -q -m initial

config5="$repo_root/.xsm-local/swarm-backlog.yaml"
echo "{}" >"$config5"
counter_file5="$tmpdir/case5_count"
echo 0 >"$counter_file5"
fake_path_change=$(make_fake_xsm "path_change" "
trap 'exit 75' TERM
count=\$(cat \"$counter_file5\")
count=\$((count + 1))
echo \"\$count\" >\"$counter_file5\"
if [ \"\$count\" -eq 1 ]; then
  while true; do sleep 0.1; done
fi
exit 5
")
audit_log="$tmpdir/restarts.jsonl"
(
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ "$(cat "$counter_file5")" == "1" ]] && break
    sleep 0.1
  done
  echo "two" >"$repo_root/xenon/packages/xsm/src/xsm/marker.py"
  git -C "$repo_root/xenon" add packages/xsm/src/xsm/marker.py
  git -C "$repo_root/xenon" commit -q -m second
) &
updater_pid=$!
final_rc=0
output=$(XSM_RELAUNCH_AUDIT_LOG="$audit_log" XSM_RELAUNCH_DEBOUNCE_SECONDS=0 xsm_relaunch_loop "$fake_path_change" "$config5" 0 4 "$repo_root" 0.1 2>&1) || final_rc=$?
wait "$updater_pid"
final_count=$(cat "$counter_file5")
assert_eq "path-change-final-rc" 5 "$final_rc"
assert_eq "path-change-relaunch-count" 2 "$final_count"
assert_contains "path-change-message" "packages/xsm sha changed" "$output"
assert_contains "path-change-audit" "relaunch_loop_path_change" "$(cat "$audit_log")"

# Case 6: path change thrash protection (debounce).
# Two rapid changes should only result in ONE relaunch if they occur
# within the debounce window.
repo_root6="$tmpdir/repo6"
mkdir -p "$repo_root6/xenon/packages/xsm/src/xsm" "$repo_root6/.xsm-local"
git -C "$repo_root6/xenon" init -q
git -C "$repo_root6/xenon" config user.email "test@example.invalid"
git -C "$repo_root6/xenon" config user.name "test"
echo "one" >"$repo_root6/xenon/packages/xsm/src/xsm/marker.py"
git -C "$repo_root6/xenon" add packages/xsm/src/xsm/marker.py
git -C "$repo_root6/xenon" commit -q -m initial

config6="$repo_root6/.xsm-local/swarm-backlog.yaml"
echo "{}" >"$config6"
counter_file6="$tmpdir/case6_count"
echo 0 >"$counter_file6"
# We need the child to stay alive long enough to see both changes.
fake_debounce=$(make_fake_xsm "debounce" "
trap 'exit 75' TERM
count=\$(cat \"$counter_file6\")
count=\$((count + 1))
echo \"\$count\" >\"$counter_file6\"
if [ \"\$count\" -le 2 ]; then
  while true; do sleep 0.1; done
fi
exit 6
")

# We use a 2s debounce and 0.1s polling.
# We'll trigger two changes 0.2s apart.
(
  # Wait for the first iteration to start
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ "$(cat "$counter_file6")" == "1" ]] && break
    sleep 0.1
  done
  
  # First change -> should trigger relaunch
  echo "two" >"$repo_root6/xenon/packages/xsm/src/xsm/marker.py"
  git -C "$repo_root6/xenon" add packages/xsm/src/xsm/marker.py
  git -C "$repo_root6/xenon" commit -q -m second
  
  # Wait for second iteration to start
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ "$(cat "$counter_file6")" == "2" ]] && break
    sleep 0.1
  done
  
  # Second change -> should be DEBOUNCED
  echo "three" >"$repo_root6/xenon/packages/xsm/src/xsm/marker.py"
  git -C "$repo_root6/xenon" add packages/xsm/src/xsm/marker.py
  git -C "$repo_root6/xenon" commit -q -m third
  
  # Wait 0.5s (still within 2s debounce)
  sleep 0.5
  
  # Now kill the child manually so the loop can exit (iteration 2)
  # But wait, if we kill it, rc will be 143 (SIGTERM), which IS graceful.
  # So it would relaunch for iteration 3.
  # If it relaunches for iteration 3, then final_count will be 3.
  # If debounce worked, iteration 2 was NOT killed by the SHA change.
) &
updater_pid6=$!

# Run the loop. We expect it to exit with rc=6 (from the fake script's 3rd iteration)
# Wait, if we want it to exit after 3 iterations, we set cap=2.
# 1 (initial) + 1 (relaunch from 1st change) + 1 (manual kill or next change)
# But wait, if we want to PROVE debounce, we should see that the 2nd change
# DID NOT terminate the 2nd child.

# Let's adjust the fake script:
# count 1: sleep forever (until killed by SHA change)
# count 2: sleep for 1s then exit with rc=6
# If debounce works, child 2 sleeps for 1s and exits rc=6.
# If debounce fails, child 2 is killed by SHA change and we get child 3.

fake_debounce_v2=$(make_fake_xsm "debounce_v2" "
trap 'exit 75' TERM
count=\$(cat \"$counter_file6\")
count=\$((count + 1))
echo \"\$count\" >\"$counter_file6\"
if [ \"\$count\" -eq 1 ]; then
  while true; do sleep 0.1; done
fi
if [ \"\$count\" -eq 2 ]; then
  sleep 1.5
  exit 6
fi
exit 7
")

export XSM_RELAUNCH_DEBOUNCE_SECONDS=2
output=$(xsm_relaunch_loop "$fake_debounce_v2" "$config6" 0 4 "$repo_root6" 0.1 2>&1) || final_rc=$?
wait "$updater_pid6"
final_count=$(cat "$counter_file6")

assert_eq "debounce-final-rc" 6 "$final_rc"
assert_eq "debounce-relaunch-count" 2 "$final_count"
assert_contains "debounce-first-change" "packages/xsm sha changed" "$output"

echo
echo "All xsm_relaunch_loop tests passed."
