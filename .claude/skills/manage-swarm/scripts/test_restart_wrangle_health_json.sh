#!/usr/bin/env bash
set -euo pipefail

# Unit tests for restart_wrangle.sh health JSON parsing (xc-844w).

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export RESTART_WRANGLE_TEST_HELPERS_ONLY=1
# shellcheck source=./restart_wrangle.sh
source "$script_dir/restart_wrangle.sh"

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

assert_fails() {
  local label="$1"
  shift
  if "$@" >/tmp/restart-wrangle-health.out 2>/tmp/restart-wrangle-health.err; then
    echo "FAIL: $label"
    echo "  command unexpectedly succeeded"
    cat /tmp/restart-wrangle-health.out
    cat /tmp/restart-wrangle-health.err >&2
    exit 1
  fi
  echo "PASS: $label"
}

healthy='{"status":"ready","state_counts":{"active_working":4}}'
bad_workers='{"status":"ready","state_counts":{"stopped":2,"respawn_needed":1}}'
missing_counts='{"status":"ready"}'
malformed='{"status":"ready",'

assert_eq "status-ready" "ready" "$(restart_wrangle_health_status "$healthy")"
assert_eq "healthy-bad-worker-count" "0" "$(restart_wrangle_bad_worker_count "$healthy")"
assert_eq "bad-worker-count" "3" "$(restart_wrangle_bad_worker_count "$bad_workers")"
assert_fails "missing-state-counts-fails-unhealthy" restart_wrangle_bad_worker_count "$missing_counts"
assert_fails "malformed-json-fails-unhealthy" restart_wrangle_bad_worker_count "$malformed"
assert_fails "malformed-status-fails-unhealthy" restart_wrangle_health_status "$malformed"

echo
echo "test_restart_wrangle_health_json: OK"
