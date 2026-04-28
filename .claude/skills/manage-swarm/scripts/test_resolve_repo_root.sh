#!/usr/bin/env bash
set -euo pipefail

# Regression test for resolve_repo_root.sh — covers the xc-xq5rt failure mode
# where a worktree-local skill copy at <repo>/.worktrees/<lane>/.claude/skills
# resolved to the worktree directory (no .xsm-local) instead of the live repo
# root.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

source "$script_dir/resolve_repo_root.sh"

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" != "$expected" ]]; then
    echo "$label: expected '$expected', got '$actual'" >&2
    exit 1
  fi
}

assert_fails() {
  local label="$1"
  shift

  if "$@" >/dev/null 2>&1; then
    echo "$label: command unexpectedly succeeded" >&2
    exit 1
  fi
}

# Build a fake live repo with .xsm-local/swarm-backlog.yaml and a worktree-
# local skill copy mirroring the production layout under .worktrees/<lane>/.
fake_repo="$tmpdir/xenota"
worktree_scripts="$fake_repo/.worktrees/worker-codex-1/.claude/skills/manage-swarm/scripts"
canonical_scripts="$fake_repo/.claude/skills/manage-swarm/scripts"

mkdir -p "$fake_repo/.xsm-local" "$worktree_scripts" "$canonical_scripts"
printf 'fake-config\n' >"$fake_repo/.xsm-local/swarm-backlog.yaml"

# Resolve the symlinked tmpdir to its real path (macOS /tmp -> /private/tmp).
real_fake_repo="$(cd "$fake_repo" && pwd)"

# Case 1: invocation from a worktree-local skill copy must walk past the
# worktree (no .xsm-local) up to the live repo root.
unset XENOTA_REPO
result="$(resolve_xenota_repo_root "$worktree_scripts")"
assert_eq "worktree skill-copy resolution" "$real_fake_repo" "$result"

# Case 2: canonical invocation from the in-repo skill copy must resolve to the
# same live repo root.
unset XENOTA_REPO
result="$(resolve_xenota_repo_root "$canonical_scripts")"
assert_eq "canonical skill resolution" "$real_fake_repo" "$result"

# Case 3: XENOTA_REPO override takes precedence even when a real .xsm-local
# would otherwise be discovered. Operators can pin the resolver explicitly.
XENOTA_REPO="/some/explicit/path" result="$(XENOTA_REPO="/some/explicit/path" resolve_xenota_repo_root "$worktree_scripts")"
assert_eq "XENOTA_REPO override" "/some/explicit/path" "$result"

# Case 4: when no ancestor has .xsm-local/swarm-backlog.yaml, resolution must
# fail (rather than silently returning a wrong path).
no_xsm_dir="$tmpdir/no-xsm/sub"
mkdir -p "$no_xsm_dir"
unset XENOTA_REPO
assert_fails "missing .xsm-local fails" resolve_xenota_repo_root "$no_xsm_dir"

# Case 5: send_worker_message.sh must surface a clear error when invoked from
# a directory tree with no .xsm-local and no XENOTA_REPO override. We invoke
# the production script directly (not a copy) and point its script_dir at the
# fake by symlinking a fake scripts dir under a no-.xsm-local tree. The
# message in stderr is the regression check.
fake_scripts="$tmpdir/no-xsm/.claude/skills/manage-swarm/scripts"
mkdir -p "$fake_scripts"
ln -s "$script_dir/resolve_repo_root.sh" "$fake_scripts/resolve_repo_root.sh"
cp "$script_dir/send_worker_message.sh" "$fake_scripts/send_worker_message.sh"
chmod +x "$fake_scripts/send_worker_message.sh"

set +e
err="$(unset XENOTA_REPO; "$fake_scripts/send_worker_message.sh" worker-claude-1 "ping" 2>&1 1>/dev/null)"
rc=$?
set -e

if [[ $rc -eq 0 ]]; then
  echo "send_worker_message in unrooted tree should fail" >&2
  exit 1
fi
if ! grep -q "could not locate live xenota repo root" <<<"$err"; then
  echo "send_worker_message error should mention repo-root resolution; got: $err" >&2
  exit 1
fi

# Case 6: restart helpers must source the resolver and call
# resolve_xenota_repo_root rather than re-deriving repo_root with the fragile
# ``cd "$script_dir/../../../.."`` traversal. xc-fqskk: that traversal silently
# resolves to the worktree (e.g. .worktrees/landing) when the helper is invoked
# from a worktree-local skill copy, which lacks .xsm-local/log and breaks
# health checks.
restart_helpers=(
  restart_wrangle.sh
  restart_local_xsm.sh
  start_supervisor_and_landing.sh
  p0_scan.sh
)
for helper in "${restart_helpers[@]}"; do
  helper_path="$script_dir/$helper"
  if grep -Fq 'script_dir/../../../..' "$helper_path"; then
    echo "$helper still derives repo_root via brittle ../../../.. traversal" >&2
    exit 1
  fi
  if ! grep -Fq 'resolve_xenota_repo_root' "$helper_path"; then
    echo "$helper does not call resolve_xenota_repo_root" >&2
    exit 1
  fi
done

echo "test_resolve_repo_root: OK"
