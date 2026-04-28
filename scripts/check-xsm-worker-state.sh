#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

matches_worker_metadata() {
  awk '$0 == ".xsm-worker.json" || $0 ~ /\/\.xsm-worker\.json$/'
}

tracked_worker_metadata="$(git ls-files | matches_worker_metadata || true)"
staged_worker_metadata="$(
  git diff --cached --name-only --diff-filter=ACMR | matches_worker_metadata || true
)"

if [[ -n "${tracked_worker_metadata}" || -n "${staged_worker_metadata}" ]]; then
  {
    echo "xsm worker-state preflight failed: .xsm-worker.json is runtime metadata"
    echo "and must not be tracked or added to xenota pointer PRs."
    if [[ -n "${tracked_worker_metadata}" ]]; then
      echo
      echo "Tracked worker metadata:"
      echo "${tracked_worker_metadata}"
    fi
    if [[ -n "${staged_worker_metadata}" ]]; then
      echo
      echo "Staged worker metadata:"
      echo "${staged_worker_metadata}"
    fi
    echo
    echo "Keep worker session state local/ignored. Pointer PRs should include"
    echo "stable review metadata in the PR body instead: bead id/title, branch,"
    echo "submodule PR links, test evidence, and provenance."
  } >&2
  exit 1
fi

echo "xsm worker-state preflight passed"
