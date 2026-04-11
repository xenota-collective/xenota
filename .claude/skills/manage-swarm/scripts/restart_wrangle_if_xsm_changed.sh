#!/usr/bin/env bash
set -euo pipefail

# Detect whether a landed change affects XSM runtime and restart wrangle if so.
# Usage: restart_wrangle_if_xsm_changed.sh <before-sha> <after-sha> [submodule-path]
#
# before-sha / after-sha: xenon submodule commit range to diff
# submodule-path: path to xenon checkout (default: xenon/)

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <before-sha> <after-sha> [submodule-path]" >&2
  exit 2
fi

before="$1"
after="$2"
submodule="${3:-xenon}"

# Paths that affect the live XSM runtime
xsm_paths=(
  "packages/xsm/src/xsm/"
  "packages/xsm/pyproject.toml"
)

changed_files="$(git -C "$submodule" diff --name-only "$before" "$after" 2>/dev/null || true)"

if [[ -z "$changed_files" ]]; then
  echo "restart_wrangle_if_xsm_changed: no diff between $before..$after — skipping" >&2
  exit 0
fi

xsm_affected=false
for prefix in "${xsm_paths[@]}"; do
  if grep -q "^${prefix}" <<< "$changed_files"; then
    xsm_affected=true
    break
  fi
done

if [[ "$xsm_affected" == "false" ]]; then
  echo "restart_wrangle_if_xsm_changed: no XSM-affecting paths in diff — skipping" >&2
  exit 0
fi

echo "restart_wrangle_if_xsm_changed: XSM-affecting changes detected, rebuilding and restarting wrangle" >&2

# Reinstall XSM package so the running daemon picks up new code
if [[ -f "$submodule/packages/xsm/pyproject.toml" ]]; then
  echo "restart_wrangle_if_xsm_changed: reinstalling xsm package" >&2
  (cd "$submodule/packages/xsm" && uv tool install --force --editable . 2>&1) || {
    echo "restart_wrangle_if_xsm_changed: WARNING — xsm reinstall failed, restart may use stale code" >&2
  }
fi

# Restart wrangle via the existing restart script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$script_dir/restart_wrangle.sh"
