#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "usage: $0 <epic> <landing-agent> <agent> <submodule-repo> <pr-stack>" >&2
  exit 2
fi

epic="$1"
landing_agent="$2"
agent="$3"
submodule_repo="$4"
pr_stack="$5"

exec gt sling land-submodule-stack --on "$epic" xenota --crew "$landing_agent" --agent "$agent" --stdin <<EOF
Parent epic: $epic
Submodule repo: $submodule_repo
Top-level repo: xenota
Current PR stack: $pr_stack
EOF
