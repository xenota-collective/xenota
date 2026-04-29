# Objective Patrol Skill

Guide Product Owner and supervisor lanes through the objective-driven swarm lifecycle.

## Overview

Swarm objectives are high-level outcomes (e.g. "migrate to staged pipeline") that
live above individual beads. This skill helps you patrol the objective registry,
decompose objectives into beads, and record progress decisions.

## Objectives Registry

The source of truth is `xenon/packages/xsm/src/xsm/objectives.yaml`.
Use the `xsm objectives` CLI to interact with it.

## Patrol Workflow

### 1. Discover Active Objectives

List all objectives to see which ones need attention:

```bash
xsm objectives list --config $XSM_CONFIG
```

### 2. Inspect an Objective

For each objective in `decomposing`, `active`, or `stable_long_lived` status,
inspect its intent and decomposition:

```bash
xsm objectives show <objective-id> --config $XSM_CONFIG
```

### 3. Move Objectives Forward

#### Status: `proposed` (Supervisor only)
- Decide whether to accept the objective.
- If accepted, move to `accepted` and record rationale.

#### Status: `accepted` or `decomposing` (Product Owner / Supervisor)
- Check `bd` for related epics or beads.
- If none exist, create a parent epic via `bd create`.
- Set `metadata.objective_id=<id>` on the epic.
- Decompose the epic into tactical implementation beads.
- Update the objective's `audit_log` with `decision: decompose`.

#### Status: `active` or `gated` (Supervisor)
- Check progress of child beads.
- If all implementation beads for a short-lived objective are closed,
  run the completion evaluator (see xc-9kjq.3).
- Record the decision in the `audit_log`.

### 4. Recording Decisions

Every patrol session must conclude with at least one audit log entry for the
inspected objective(s). Use `xsm objectives audit-add` (if implemented) or
edit `objectives.yaml` directly.

## Scripts

- `scripts/patrol.sh`: List and show active objectives.
- `scripts/decompose.sh <obj-id> <epic-id> <rationale>`: Link an epic to an
  objective and update the audit log.

## Rules

- **Reverse Lookup**: Beads belonging to an objective should have a label
  `objective:<id>`.
- **Audit-First**: Never change an objective's status without an `audit_log`
  entry.
- **PO Boundary**: Product Owner lanes can propose and decompose; only the
  supervisor lane can accept, complete, or abandon objectives.
