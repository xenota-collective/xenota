#!/opt/homebrew/bin/bash
# Objective patrol helper for Product Owner / supervisor lanes.

set -euo pipefail

# Default config if not set
XSM_CONFIG="${XSM_CONFIG:-/Users/jv/projects/xenota/.xsm-local/swarm-backlog.yaml}"

echo "--- Swarm Objectives Patrol ---"

# 1. List objectives
echo "Active Objectives:"
xsm objectives list --config "$XSM_CONFIG"

# 2. Pick one that needs attention (simplified: just show detail for the first one that isn't terminal)
NEEDS_ATTENTION=$(xsm objectives list --config "$XSM_CONFIG" | grep -vE "complete|abandoned" | head -n 1 | awk '{print $1}')

if [[ -z "$NEEDS_ATTENTION" ]]; then
  echo "No active objectives need attention."
  exit 0
fi

echo ""
echo "Inspecting: $NEEDS_ATTENTION"
xsm objectives show "$NEEDS_ATTENTION" --config "$XSM_CONFIG"

echo ""
echo "Next step: decompose or evaluate $NEEDS_ATTENTION and record your decision in the audit log."
