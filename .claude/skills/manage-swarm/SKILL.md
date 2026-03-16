---
name: manage-swarm
description: Coordinate multiple Xenota crew workers and polecats across implementation, review, manual testing, and landing. Use when managing the swarm across crew, dispatching epics across crew, keeping workers unblocked and moving, enforcing opposite-flavor review gates, requiring manual testing plans and manual execution passes, and handing completed feature stacks to the landing workflow.
---

# Manage Swarm

Use this skill when coordinating active work across `xenota` crew and polecats.

This skill is for operational wrangling, not implementation:
- assign epics or child beads across crew
- keep every worker moving unless they are genuinely blocked
- enforce review and manual testing gates before declaring work done
- hand completed stacks to the landing workflow

## Core Rules

- Prefer direct evidence from live tmux panes over bead status when checking whether someone is actually working.
- An active epic is only progressing if someone is actively working on it now, or it is explicitly waiting on another active worker or gate.
- A completed slice with nobody actively pushing the next slice does not count as progress.
- If a worker is idle at a handoff point and still owns the active epic, nudge them directly onto the next slice.
- If a worker is moving, do not interrupt just to restate bead status.
- If a worker is blocked by tracker noise or Dolt config but git/code work can continue, tell them to keep going.
- If a worker is blocked by another person or unresolved review findings, make that explicit and route the dependency.

## Crew Allocation

When splitting work across crew:
- assign one epic per crew member unless there is a good reason to split smaller
- require a feature branch and PR-based landing for each workstream
- ask for the exact branch name, first bead, and next 2 planned beads
- when a crew member finishes an epic, reaches a real handoff point, or goes idle while still owning an active epic, immediately reassign them or push them onto the next slice

Suggested commands:

```bash
cd /Users/jv/gt/xenota/mayor/rig
bd update <epic> -a xenota/crew/<name>

gt nudge xenota/crew/<name> --mode immediate --message 'Reply with exact branch name, first bead, next 2 beads, and confirm PR-based landing.'
```

## Check-Ins

Default check-in order:
1. Read the worker pane
2. Read the active polecat pane if there is a gate in progress
3. Only then look at bead/PR state for corroboration

Commands:

```bash
tmux capture-pane -pt xc-crew-<name>:0.0 | tail -n 120
tmux capture-pane -pt xc-<polecat>:0.0 | tail -n 120
gt polecat list xenota
cd /Users/jv/gt/xenota/mayor/rig && bd show <bead>
```

Interpretation:
- fresh prompt after a completed action = likely idle, give next action
- long-running tool/test output = working, do not redirect unless clearly wedged
- repeated failed command or obvious confusion = intervene immediately

Idleness test:
- worker idle + active epic still assigned + no explicit active dependency = not acceptable, intervene now
- worker idle + epic already handed to a reviewer/manual tester/landing owner = acceptable
- recent commits or PRs without current active work do not count as progress

Claude vim-mode note:
- Some Claude crew panes run with vim-style input modes.
- In those panes, injected text may appear to "not land" if the client is still in a modal editor state.
- Before concluding that a Claude pane ignored a nudge, send `Escape` first, then inject the instruction.
- If `gt nudge --mode immediate` does not visibly surface in-pane, try tmux injection only after the `Escape` reset.
- If the pane still does not consume input after an `Escape`-first injection, restart the session rather than assuming the epic is progressing.

Escape-first tmux pattern for Claude panes:

```bash
tmux send-keys -t xc-crew-<name>:0.0 Escape
tmux set-buffer -- '<instruction>'
tmux paste-buffer -t xc-crew-<name>:0.0
tmux send-keys -t xc-crew-<name>:0.0 Enter
```

## Review Gate

For code-bearing work, require an opposite-flavor review before calling the work done:
- Codex implementation -> Claude polecat review
- Claude implementation -> Codex polecat review

Rules:
- review the full feature branch/PR stack, not just one file
- findings must be posted back on the epic or designated review bead
- if findings exist, send them back to the implementation owner before manual testing

Pattern:
1. Create a dedicated review child bead if needed
2. Dispatch a polecat of the opposite flavor
3. Require comments on the epic or review bead

Examples:

```bash
cd /Users/jv/gt/xenota/mayor/rig
bd create --silent --parent <epic> -t task -p P1 "Run full <agent> polecat code review for <epic>"

gt sling <review-bead> xenota --agent <claude|codex> --no-convoy --stdin <<'EOF'
Review the full feature stack.
Post findings on the epic or review bead.
EOF
```

## Manual Testing Plan Gate

Before a separate manual tester runs, require the implementation owner to write a concrete manual testing plan on the epic.

The plan must include:
- exact setup and environment
- commands to run
- data state / fixtures
- what to exercise manually
- pass/fail criteria
- what remains untestable before later integration

Nudge pattern:

```bash
gt nudge xenota/crew/<name> --mode immediate --message 'Write a detailed manual testing plan as comments on <epic> with setup, commands, pass/fail, and deferred integration gaps.'
```

## Manual Execution Gate

Manual execution should be done by a separate worker or polecat, not by the implementer.

Rules:
- execute the plan in practice; do not restate it
- post concrete results, commands run, pass/fail, and deviations
- clearly separate executed coverage from later integration gaps
- verify the results are actually posted on the parent epic or designated manual-test bead before allowing landing to proceed

If the epic is already hooked to a review worker, create a child bead for manual execution and dispatch that instead of re-hooking the epic.

Example:

```bash
cd /Users/jv/gt/xenota/mayor/rig
bd create --silent --parent <epic> -t task -p P1 "Execute manual testing plan for <epic>"

gt sling <manual-test-bead> xenota --agent <claude|codex> --no-convoy --stdin <<'EOF'
Execute the manual testing plan posted on the parent epic.
Post results back on the parent epic.
EOF
```

## Landing

Do not let implementation owners improvise submodule landing.

For submodule-backed features:
- use the `land-submodule-stack` formula
- keep submodule PRs and the top-level pointer PR as one coordinated landing unit
- delay submodule merges until the top-level PR is integration-tested and ready to merge

Current landing formula:
- `land-submodule-stack`

Dispatch pattern:

```bash
gt sling land-submodule-stack --on <epic> xenota --crew <landing-agent> --agent codex --stdin <<'EOF'
Parent epic: <epic>
Submodule repo: xenon
Top-level repo: xenota
Current PR stack: <list>
EOF
```

## Reassignment Rule

If a crew member finishes or reaches a real wait-state:
- reassign them immediately
- if the old context is heavy, clear/restart the session first

Session reset pattern:

```bash
tmux kill-session -t xc-crew-<name>
gt crew start xenota <name> --agent <codex|claude>
```

Then nudge the fresh session with the new assignment.

For Claude sessions that may be in vim mode:
- try the `Escape`-first tmux pattern before restarting
- if the pane still stays at a prompt without consuming the instruction, restart and resend immediately

## Default Manage-Swarm Loop

1. Check all crew panes.
2. Check active gate polecats.
3. For each active epic, verify there is a worker actively moving it now or an explicit active dependency.
4. Identify idle vs blocked vs moving.
5. Nudge idle owners onto the next slice immediately.
6. Convert completed implementation into review gate.
7. Convert completed review into manual execution gate.
8. Hand complete stacks to `land-submodule-stack`.
9. Keep one summary in your own notes of who owns what, which PRs exist, and what gate is still open.

## Do Not

- Do not trust only `bd show` or `gt status` when determining whether someone is working.
- Do not treat recent commits, open PRs, or a completed slice as proof that an active epic is progressing.
- Do not start manual testing before review findings are resolved.
- Do not merge submodule PRs early just because submodule tests pass.
- Do not leave a completed worker idle when another epic or gate needs an owner.
