#!/usr/bin/env bash
# Locate the live xenota repo root from a script copy that may live inside a
# worktree (e.g. <repo>/.worktrees/<lane>/.claude/skills/manage-swarm/scripts).
# The live root is whichever ancestor directory contains
# .xsm-local/swarm-backlog.yaml. Honors XENOTA_REPO when explicitly set so
# operators can override the search.

resolve_xenota_repo_root() {
  local start_dir="${1:-$PWD}"

  if [[ -n "${XENOTA_REPO:-}" ]]; then
    printf '%s\n' "$XENOTA_REPO"
    return 0
  fi

  local dir
  dir="$(cd "$start_dir" 2>/dev/null && pwd)" || return 1

  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -f "$dir/.xsm-local/swarm-backlog.yaml" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  return 1
}
