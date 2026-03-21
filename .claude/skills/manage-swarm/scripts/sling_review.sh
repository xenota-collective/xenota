#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <review-bead> <agent: claude|codex> <crew>" >&2
  exit 2
fi

review_bead="$1"
agent="$2"
crew="$3"

exec gt sling "$review_bead" "$crew" --agent "$agent" --no-convoy --stdin <<'EOF'
Review the full feature stack.
Post findings on the epic or review bead.
EOF
