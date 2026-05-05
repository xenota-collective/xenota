#!/usr/bin/env bash
# verify_xenon_on_main.sh — assert the live xenon submodule checkout is on
# `main` at the SHA registered in the xenota outer pointer.
#
# Live xsm reads source from the xenon working tree (editable install). When
# the working tree silently drifts to a feature branch, xsm runs ahead-of-main
# code, the relaunch loop tracks the wrong sha, and post-merge landings appear
# correct in the outer pointer while the runtime is on something else.
#
# Run this after every PR merge + pointer bump, and before any restart_local_xsm.
#
# Exit codes: 0 OK, 1 DRIFT (current branch != main or HEAD != registered SHA).

set -euo pipefail

REPO="${REPO:-/Users/jv/projects/xenota}"

cd "$REPO"
registered=$(git ls-tree HEAD xenon | awk '{print $3}')
if [[ -z "$registered" ]]; then
  echo "verify_xenon_on_main: cannot read registered submodule SHA" >&2
  exit 1
fi

cd "$REPO/xenon"
branch=$(git branch --show-current)
head=$(git rev-parse HEAD)

ok=1
if [[ "$branch" != "main" ]]; then
  echo "verify_xenon_on_main: DRIFT — xenon is on '$branch', expected 'main'" >&2
  ok=0
fi
if [[ "$head" != "$registered" ]]; then
  echo "verify_xenon_on_main: DRIFT — xenon HEAD is $head, registered pointer is $registered" >&2
  ok=0
fi

if (( ok == 1 )); then
  echo "verify_xenon_on_main: OK (main @ $head)"
  exit 0
fi

cat >&2 <<EOF
verify_xenon_on_main: recover with:
  cd $REPO/xenon
  git checkout main
  git fetch origin main
  git reset --hard $registered
  # then: bash $REPO/.claude/skills/manage-swarm/scripts/restart_local_xsm.sh
EOF
exit 1
