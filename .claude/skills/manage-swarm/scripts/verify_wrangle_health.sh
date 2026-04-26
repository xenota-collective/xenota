#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(
  cd "$script_dir/../../../.." && pwd
)"

default_config="$repo_root/.xsm-local/swarm-backlog.yaml"
live_config="/Users/jv/gt/xenota/.xsm/swarm.yaml"

config_path="${1:-${XSM_CONFIG:-}}"
if [[ -z "$config_path" ]]; then
  if [[ -f "$default_config" ]]; then
    config_path="$default_config"
  else
    config_path="$live_config"
  fi
fi

xsm_bin="${2:-${XSM_BIN:-$repo_root/xenon/packages/xsm/.venv/bin/xsm}}"
attempts="${XSM_HEALTH_ATTEMPTS:-6}"
interval="${XSM_HEALTH_INTERVAL_SECONDS:-5}"

if [[ ! -f "$config_path" ]]; then
  echo "verify_wrangle_health: missing config: $config_path" >&2
  exit 2
fi

if [[ ! -x "$xsm_bin" ]]; then
  echo "verify_wrangle_health: missing executable runtime: $xsm_bin" >&2
  exit 2
fi

last_payload=""
last_rc=0
for (( attempt = 1; attempt <= attempts; attempt += 1 )); do
  last_rc=0
  last_payload="$("$xsm_bin" monitor --config "$config_path" --once --json 2>&1)" || last_rc=$?
  if [[ "$last_rc" -eq 0 ]] && XSM_HEALTH_PAYLOAD="$last_payload" python3 - "$attempt" "$attempts" <<'PY'
import json
import os
import sys

attempt = int(sys.argv[1])
attempts = int(sys.argv[2])
try:
    payload = json.loads(os.environ["XSM_HEALTH_PAYLOAD"])
except json.JSONDecodeError as exc:
    print(
        f"verify_wrangle_health: monitor returned non-json payload on attempt {attempt}/{attempts}: {exc}",
        file=sys.stderr,
    )
    sys.exit(3)
status = payload.get("status")
counts = payload.get("state_counts") or {}
bad = {
    state: int(counts.get(state) or 0)
    for state in ("stopped", "respawn_needed")
    if int(counts.get(state) or 0) > 0
}
if status != "ready":
    print(
        f"verify_wrangle_health: monitor status={status!r} on attempt {attempt}/{attempts}",
        file=sys.stderr,
    )
    sys.exit(3)
if bad:
    formatted = ", ".join(f"{state}={count}" for state, count in sorted(bad.items()))
    print(
        f"verify_wrangle_health: unhealthy state_counts on attempt {attempt}/{attempts}: {formatted}",
        file=sys.stderr,
    )
    sys.exit(3)
print(
    "verify_wrangle_health: healthy "
    f"status=ready agent_count={payload.get('agent_count')} state_counts={counts}"
)
PY
  then
    exit 0
  fi

  if [[ "$attempt" -lt "$attempts" ]]; then
    sleep "$interval"
  fi
done

echo "verify_wrangle_health: failed after $attempts attempt(s)" >&2
if [[ "$last_rc" -ne 0 ]]; then
  echo "verify_wrangle_health: monitor exited with rc=$last_rc" >&2
fi
printf '%s\n' "$last_payload" >&2
exit 1
