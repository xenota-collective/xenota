#!/opt/homebrew/bin/bash
# Objective decomposition helper.

set -euo pipefail

OBJ_ID="$1"
EPIC_ID="$2"
RATIONALE="$3"

XSM_CONFIG="${XSM_CONFIG:-/Users/jv/projects/xenota/.xsm-local/swarm-backlog.yaml}"

echo "Linking epic $EPIC_ID to objective $OBJ_ID..."

# 1. Update bd metadata
bd update "$EPIC_ID" --set-metadata objective_id="$OBJ_ID"

# 2. Add label
bd update "$EPIC_ID" --add-label "objective:$OBJ_ID"

# 3. Update objective decomposition
xsm objectives decompose "$OBJ_ID" --parent "$EPIC_ID" --config "$XSM_CONFIG"

# 4. Record audit entry
xsm objectives audit-add "$OBJ_ID" --decision decompose --actor "$ROLE" --rationale "$RATIONALE" --next-action "Deliver child beads." --config "$XSM_CONFIG"

echo "Done."
