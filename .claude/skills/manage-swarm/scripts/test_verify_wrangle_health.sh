#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

config="$tmp_dir/swarm.yaml"
fake_xsm="$tmp_dir/xsm"
payload="$tmp_dir/payload.json"

printf 'repo: /tmp/repo\nagents: []\n' >"$config"
cat >"$fake_xsm" <<'SH'
#!/usr/bin/env bash
cat "$XSM_FAKE_PAYLOAD"
SH
chmod +x "$fake_xsm"

cat >"$payload" <<'JSON'
{"status":"ready","agent_count":4,"state_counts":{"active_working":2,"parked_unassigned":2}}
JSON
XSM_FAKE_PAYLOAD="$payload" XSM_HEALTH_ATTEMPTS=1 "$script_dir/verify_wrangle_health.sh" "$config" "$fake_xsm" >/dev/null

cat >"$payload" <<'JSON'
{"status":"ready","agent_count":4,"state_counts":{"active_working":2,"stopped":1,"respawn_needed":1}}
JSON
rc=0
XSM_FAKE_PAYLOAD="$payload" XSM_HEALTH_ATTEMPTS=1 "$script_dir/verify_wrangle_health.sh" "$config" "$fake_xsm" >/tmp/verify_wrangle_health.out 2>/tmp/verify_wrangle_health.err || rc=$?
if [[ "$rc" -eq 0 ]]; then
  echo "expected health verifier to fail on stopped/respawn_needed counts" >&2
  exit 1
fi
if ! grep -Fq "respawn_needed=1" /tmp/verify_wrangle_health.err || ! grep -Fq "stopped=1" /tmp/verify_wrangle_health.err; then
  echo "expected health verifier to report stopped and respawn_needed counts" >&2
  cat /tmp/verify_wrangle_health.err >&2
  exit 1
fi

echo "test_verify_wrangle_health: OK"
