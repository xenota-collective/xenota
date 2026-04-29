#!/usr/bin/env bash
# xc-zmpda.3: regression tests for restart_xsm.sh + xsm_relaunch_loop.sh.
#
# Exercises the post-merge auto-restart path end-to-end against fake ps /
# kill / xsm binaries so the test runs hermetically without touching the
# real swarm. Run with:
#   bash .claude/skills/manage-swarm/tests/test_restart_xsm.sh

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../../.." && pwd)"
restart_xsm="$repo_root/.claude/skills/manage-swarm/scripts/restart_xsm.sh"
relaunch_loop="$repo_root/.claude/skills/manage-swarm/scripts/xsm_relaunch_loop.sh"

if [[ ! -x "$restart_xsm" ]]; then
  chmod +x "$restart_xsm"
fi
if [[ ! -x "$relaunch_loop" ]]; then
  chmod +x "$relaunch_loop"
fi

tmp_root="$(mktemp -d)"
trap 'rm -rf "$tmp_root"' EXIT

config_path="$tmp_root/swarm-backlog.yaml"
log_path="$tmp_root/.xsm-local/restart_xsm.log"
mkdir -p "$tmp_root/.xsm-local"
echo "fake config" > "$config_path"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "  PASS: $1"
}

# ---------------------------------------------------------------------------
# restart_xsm.sh
# ---------------------------------------------------------------------------

echo "test_restart_xsm: restart_xsm.sh"

# Test 1: no live xsm wrangle process — exit 0, audit-log no_op.
ps_fixture_empty="echo "
RESTART_XSM_PS="$ps_fixture_empty" \
  RESTART_XSM_LOG="$log_path" \
  RESTART_XSM_KILL="true" \
  XENOTA_REPO="$tmp_root" \
  bash "$restart_xsm" --config "$config_path" --source test --pr xenota#999 --sha deadbeef \
    > "$tmp_root/out1" 2>&1 \
  || fail "no-op exit was non-zero (got $?)"

grep -q "outcome=no_op" "$log_path" \
  || fail "no_op outcome missing from audit log"
grep -q "source=test" "$log_path" \
  || fail "source label missing from audit log"
grep -q "pr=xenota#999" "$log_path" \
  || fail "pr ref missing from audit log"
grep -q "sha=deadbeef" "$log_path" \
  || fail "sha ref missing from audit log"
pass "no live xsm wrangle -> exit 0 + audit no_op with provenance"

# Test 2: dry-run skips the real kill.
> "$log_path"
ps_fixture_script="$tmp_root/ps_fixture.sh"
cat > "$ps_fixture_script" <<EOF
#!/usr/bin/env bash
printf '%s\n' '12345 xsm wrangle --config $config_path'
EOF
chmod +x "$ps_fixture_script"

RESTART_XSM_PS="$ps_fixture_script" \
  RESTART_XSM_LOG="$log_path" \
  RESTART_XSM_KILL="true" \
  XENOTA_REPO="$tmp_root" \
  bash "$restart_xsm" --config "$config_path" --dry-run --source post-merge \
    > "$tmp_root/out2" 2>&1 \
  || fail "dry-run exit was non-zero (got $?)"
grep -q "outcome=dry_run" "$log_path" \
  || fail "dry_run outcome missing from audit log"
grep -q "pids=12345" "$log_path" \
  || fail "dry_run did not record pid"
pass "dry-run audit-logs SIGTERM target without invoking kill"

# Test 3: live PID exits between attempts -> SIGTERM acknowledged.
> "$log_path"
ps_state="$tmp_root/ps_state"
echo "alive" > "$ps_state"
ps_fixture_script="$tmp_root/ps_fixture.sh"
cat > "$ps_fixture_script" <<EOF
#!/usr/bin/env bash
state="\$(cat "$ps_state")"
if [[ "\$state" == "alive" ]]; then
  printf '%s\n' '12345 xsm wrangle --config $config_path'
fi
EOF
chmod +x "$ps_fixture_script"

kill_fixture_script="$tmp_root/kill_fixture.sh"
cat > "$kill_fixture_script" <<EOF
#!/usr/bin/env bash
# Simulate the wrapper reaping the SIGTERM by flipping ps state to dead.
echo "dead" > "$ps_state"
EOF
chmod +x "$kill_fixture_script"

RESTART_XSM_PS="$ps_fixture_script" \
  RESTART_XSM_LOG="$log_path" \
  RESTART_XSM_KILL="$kill_fixture_script" \
  XENOTA_REPO="$tmp_root" \
  bash "$restart_xsm" --config "$config_path" --wait 5 --source post-merge --pr xenon#1234 \
    > "$tmp_root/out3" 2>&1 \
  || fail "restart with successful SIGTERM exit was non-zero"
grep -q "outcome=restarted" "$log_path" \
  || fail "restarted outcome missing from audit log"
grep -q "pids=12345" "$log_path" \
  || fail "restarted audit log missing target pid"
pass "live xsm process -> SIGTERM acknowledged + audit restarted"

# Test 4: PID does not exit before the deadline -> exit 1, timeout audit.
> "$log_path"
echo "alive" > "$ps_state"  # restore alive state for this test
# Use 'true' for kill so the ps fixture keeps reporting "alive" indefinitely.
rc=0
RESTART_XSM_PS="$ps_fixture_script" \
  RESTART_XSM_LOG="$log_path" \
  RESTART_XSM_KILL="true" \
  XENOTA_REPO="$tmp_root" \
  bash "$restart_xsm" --config "$config_path" --wait 1 --source post-merge \
    > "$tmp_root/out4" 2>&1 || rc=$?
[[ "$rc" -eq 1 ]] || fail "stuck PID should exit 1, got $rc"
grep -q "outcome=timeout" "$log_path" \
  || fail "timeout outcome missing from audit log"
pass "stuck xsm process -> exit 1 + audit timeout"

# Test 5: --help prints usage without crashing (smoke test for arg parsing).
help_rc=0
bash "$restart_xsm" --help > "$tmp_root/help" 2>&1 || help_rc=$?
[[ "$help_rc" -eq 0 ]] || fail "--help should exit 0, got $help_rc"
grep -q "restart_xsm" "$tmp_root/help" \
  || fail "--help output missing script name"
pass "--help prints usage and exits 0"

# ---------------------------------------------------------------------------
# xsm_relaunch_loop.sh
# ---------------------------------------------------------------------------

echo "test_restart_xsm: xsm_relaunch_loop.sh"

xsm_state="$tmp_root/xsm_state"
fake_xsm="$tmp_root/fake_xsm.sh"
audit_path="$tmp_root/relaunch_audit.log"

# Test 6: SIGTERM exit (rc=143) is treated as graceful and triggers relaunch.
echo "0" > "$xsm_state"
cat > "$fake_xsm" <<EOF
#!/usr/bin/env bash
# args: wrangle --config <path> --json
count=\$(cat "$xsm_state")
count=\$((count + 1))
echo "\$count" > "$xsm_state"
case "\$count" in
  1) exit 143 ;;   # SIGTERM (post-merge hook signal)
  2) exit 75 ;;    # graceful self-exit
  *) exit 0 ;;     # final clean exit -> stop the loop via cap
esac
EOF
chmod +x "$fake_xsm"

XSM_RELAUNCH_LOOP_SHA_CMD="" \
  XSM_RELAUNCH_LOOP_AUDIT="$audit_path" \
  bash "$relaunch_loop" "$fake_xsm" "$config_path" 0 2 \
    > "$tmp_root/out6" 2>&1
final_count="$(cat "$xsm_state")"
[[ "$final_count" -ge 3 ]] \
  || fail "relaunch loop should have respawned at least 3 times (cap=2 means 3 attempts), got $final_count"
grep -q "rc=143" "$audit_path" \
  || fail "audit log missing rc=143 graceful marker"
pass "SIGTERM (rc=143) treated as graceful -> auto-respawn"

# Test 7: non-graceful exit (rc=1) breaks the loop after one attempt.
echo "0" > "$xsm_state"
cat > "$fake_xsm" <<EOF
#!/usr/bin/env bash
count=\$(cat "$xsm_state")
count=\$((count + 1))
echo "\$count" > "$xsm_state"
exit 1
EOF
chmod +x "$fake_xsm"

loop_rc=0
XSM_RELAUNCH_LOOP_SHA_CMD="" \
  XSM_RELAUNCH_LOOP_AUDIT="$audit_path" \
  bash "$relaunch_loop" "$fake_xsm" "$config_path" 0 5 \
    > "$tmp_root/out7" 2>&1 || loop_rc=$?
final_count="$(cat "$xsm_state")"
[[ "$loop_rc" -eq 1 ]] \
  || fail "non-graceful exit should propagate rc=1, got $loop_rc"
[[ "$final_count" -eq 1 ]] \
  || fail "non-graceful exit should NOT respawn, got $final_count attempts"
pass "rc=1 (non-graceful) breaks loop after one attempt"

# Test 8: SHA tracker logs xsm sha changes between iterations.
echo "0" > "$xsm_state"
sha_state="$tmp_root/sha_state"
echo "aaaa1111" > "$sha_state"

cat > "$fake_xsm" <<EOF
#!/usr/bin/env bash
count=\$(cat "$xsm_state")
count=\$((count + 1))
echo "\$count" > "$xsm_state"
case "\$count" in
  1) exit 0 ;;
  2) exit 75 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$fake_xsm"

# Each call to the SHA cmd reads sha_state, then advances it on the second
# iteration so the loop sees a SHA change.
sha_cmd_script="$tmp_root/sha_cmd.sh"
cat > "$sha_cmd_script" <<EOF
#!/usr/bin/env bash
cur="\$(cat "$sha_state")"
echo "\$cur"
# After each call, advance once so subsequent calls return the new SHA.
if [[ "\$cur" == "aaaa1111" ]]; then
  echo "bbbb2222" > "$sha_state"
fi
EOF
chmod +x "$sha_cmd_script"

> "$audit_path"
XSM_RELAUNCH_LOOP_SHA_CMD="$sha_cmd_script" \
  XSM_RELAUNCH_LOOP_AUDIT="$audit_path" \
  bash "$relaunch_loop" "$fake_xsm" "$config_path" 0 1 \
    > "$tmp_root/out8" 2>&1

grep -q "starting at sha=aaaa1111" "$audit_path" \
  || fail "audit log missing initial SHA marker"
grep -q "xsm sha changed" "$audit_path" \
  || fail "audit log missing SHA change marker"
pass "xsm SHA change between iterations is audit-logged"

# Test 9: empty XSM_RELAUNCH_LOOP_SHA_CMD disables SHA tracking cleanly.
echo "0" > "$xsm_state"
cat > "$fake_xsm" <<EOF
#!/usr/bin/env bash
count=\$(cat "$xsm_state")
count=\$((count + 1))
echo "\$count" > "$xsm_state"
exit 75
EOF
chmod +x "$fake_xsm"

> "$audit_path"
XSM_RELAUNCH_LOOP_SHA_CMD="" \
  XSM_RELAUNCH_LOOP_AUDIT="$audit_path" \
  bash "$relaunch_loop" "$fake_xsm" "$config_path" 0 1 \
    > "$tmp_root/out9" 2>&1
if grep -q "starting at sha=" "$audit_path"; then
  fail "SHA tracking should be disabled when XSM_RELAUNCH_LOOP_SHA_CMD is empty"
fi
pass "empty SHA cmd disables SHA tracking without crashing"

# Test 10: bash -n syntax check (defensive).
bash -n "$restart_xsm" || fail "restart_xsm.sh has syntax errors"
bash -n "$relaunch_loop" || fail "xsm_relaunch_loop.sh has syntax errors"
pass "bash -n clean on both scripts"

echo "test_restart_xsm.sh: PASS (10 cases)"
