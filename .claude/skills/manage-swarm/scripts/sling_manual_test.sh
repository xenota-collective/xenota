#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <manual-test-bead> <agent: claude|codex> <crew>" >&2
  exit 2
fi

manual_test_bead="$1"
agent="$2"
crew="$3"

exec gt sling "$manual_test_bead" "$crew" --agent "$agent" --no-convoy --stdin <<'EOF'
Execute the manual testing plan posted on the parent epic.
Post results back on the parent epic.
EOF
