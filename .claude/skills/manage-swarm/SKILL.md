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

Prime imperative:
- You are responsible for keeping the swarm moving.
- Do not stop at observation, diagnosis, or status reporting when an intervention is available.
- An active task that is not being progressed is intolerable.
- If an active task is sitting still, you must intervene until it is moving, explicitly rerouted, or escalated with a concrete decision request.

## Core Rules

- Prefer direct evidence from live tmux panes over bead status when checking whether someone is actually working.
- Use direct tmux pane capture as the primary evidence source. `gt peek`, hook state, dirty branches, recent commits, and bead metadata are corroboration only.
- An active epic is only progressing if someone is actively working on it now, or it is explicitly waiting on another active worker or gate.
- A completed slice with nobody actively pushing the next slice does not count as progress.
- If a worker is idle at a handoff point and still owns the active epic, nudge them directly onto the next slice.
- After sending a nudge, verify that it changed the pane state. A delivered nudge is not progress until the worker visibly resumes motion or explicitly replies with a blocker.
- The wrangler's job is to restore motion, not merely report status. Do not stop at naming the problem if you can push the next action, route the dependency, or reassign the owner yourself.
- Treat lack of movement on an active task as a failure condition requiring intervention, not as a passive status outcome.
- If a worker is moving, do not interrupt just to restate bead status.
- If a worker is blocked by tracker noise or Dolt config but git/code work can continue, tell them to keep going.
- If a worker is blocked by another person or unresolved review findings, make that explicit and route the dependency.

Status rubric:
- `active now`: the worker pane shows current execution, active reasoning, or a live gate they are presently driving
- `idle but advanced`: meaningful work was completed earlier, but no one is actively pushing the next slice now
- `assigned only`: the epic has an assignee, hook, branch, or dirty tree, but the pane does not show current motion
- `stalled`: the epic should be moving, has no valid active dependency, and nobody is currently advancing it

Conflict rule:
- if tmux activity conflicts with bead, hook, or branch state, trust tmux activity
- recent commits, open PRs, closed child beads, or dirty worktrees do not make an epic `active now`
- a hook without live pane motion is `assigned only`, not `active now`
- a completed slice waiting for the next owner is `idle but advanced`, not `active now`
- a pane sitting at a prompt with no running command or live output is not `active now`, even if scrollback shows recent edits, tests, or reasoning

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
1. Capture the worker tmux pane directly
2. Capture the active polecat pane if there is a gate in progress
3. Check for recent command/output motion in the pane
4. Only then look at hook, branch, bead, and PR state for corroboration

Commands:

```bash
/opt/homebrew/bin/tmux -L gt capture-pane -pt xc-crew-<name>:0.0 -S -120
/opt/homebrew/bin/tmux -L gt capture-pane -pt xc-<polecat>:0.0 -S -120
gt polecat list xenota
gt hook show xenota/crew/<name>
git -C /Users/jv/gt/xenota/crew/<name> branch --show-current
git -C /Users/jv/gt/xenota/crew/<name> status --short
cd /Users/jv/gt/xenota/mayor/rig && bd show <bead>
```

Interpretation:
- fresh prompt after a completed action = likely idle, give next action
- long-running tool/test output = working, do not redirect unless clearly wedged
- repeated failed command or obvious confusion = intervene immediately
- pane shows only historical summary or completed handoff text = likely idle, not active
- no live output and no valid active dependency = classify as `assigned only` or `stalled`, not `active now`

Hard check before calling anything `active now`:
1. Is the pane currently sitting at a prompt?
2. Is there a command, test, editor interaction, or other live output happening right now?

Decision:
- prompt + no live motion = not `active now`
- live motion, even without recent commits yet = `active now`
- recent scrollback without current motion = not `active now`

Idleness test:
- worker idle + active epic still assigned + no explicit active dependency = not acceptable, intervene now
- worker idle + epic already handed to a reviewer/manual tester/landing owner = acceptable
- recent commits or PRs without current active work do not count as progress
- if an active task remains idle after one intervention cycle, escalate within the ladder immediately rather than waiting

Post-nudge verification:
1. Send the nudge with an exact next action and required reply shape
2. Re-capture the pane after delivery
3. Verify one of:
   - the pane shows new live motion on the requested slice
   - the worker replies with the requested branch / file / command / blocker
4. If the pane is still sitting at a prompt with no new motion, do not mark the epic as moving
5. If the nudge landed but the pane did not change, escalate: resend with sharper instruction, use Escape-first tmux injection, or restart/reassign

Blocker handling:
1. Do not accept a blocker claim at face value if it only names another epic, boundary, or future dependency
2. Decide whether the blocker is:
   - `hard`: work truly cannot continue on this slice
   - `soft`: the worker can still take a concrete next slice, prep step, test, review, or handoff action
3. If the blocker is soft, push the worker onto the next concrete action immediately
4. If the blocker is hard, route it yourself:
   - nudge or reassign the dependency owner
   - update the relevant bead ownership if needed
   - tell the blocked worker exactly what they should do while waiting, or explicitly release/reassign them
5. A blocker reply without follow-through from the wrangler is not resolution

Weak blocker patterns that require pushback:
- "blocked on another epic" without naming the next useful step available now
- "outside ownership boundary" when prep, tests, review, documentation, or integration harness work can still proceed
- "waiting on landing" without active landing ownership or current landing motion
- "needs another subsystem" without identifying and routing the actual owner

Intervention ladder:
1. `nudge and check`
   - send an exact next action
   - re-capture the pane and verify motion or an explicit blocker reply
2. `restart worker`
   - if the pane is wedged, ignoring input, or stuck in bad modal/editor state
   - use Escape-first injection first for Claude panes, then restart if still dead
3. `reconfigure task plan and reassign`
   - if the current owner cannot productively advance the slice
   - break the work into a more concrete next bead, reroute ownership, or move the worker to a better-fit slice
4. `escalate to human`
   - only when the blocker is genuinely high-leverage and cannot be resolved through nudging, restart, or reassignment
   - escalation should include the exact blocker, what was tried, and the concrete decision needed

Never-stop rule:
- Stay in the intervention ladder until one of these is true:
  - the worker is visibly moving the task now
  - the task has been explicitly rerouted to another active owner
  - the task has been decomposed into a concrete next slice with an owner who accepted it
  - a human decision is truly required and the escalation states exactly why
- Do not leave an active task in a parked state just because you understand the situation.

Epic classification pass:
1. Read the worker pane
2. Decide whether the pane is currently at a prompt or in live motion
3. Classify the epic as `active now`, `idle but advanced`, `assigned only`, or `stalled`
4. Record any explicit dependency or gate keeping it from moving
5. If the worker is idle and still owns the active epic, push them to the next slice immediately
6. If the worker answers with a blocker, decide hard vs soft blocker and act on it yourself until ownership and next action are explicit

Required output shape for swarm status:
- `current state`: what the pane is doing right now
- `evidence now`: the specific live signal used for the classification
- `recent history`: any useful prior progress visible in scrollback
- `classification`: `active now`, `idle but advanced`, `assigned only`, or `stalled`

Separate current state from recent history. Do not merge them into one judgment.

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
4. Classify each epic as `active now`, `idle but advanced`, `assigned only`, or `stalled`.
5. Nudge idle owners onto the next slice immediately.
6. Verify the nudge changed pane state or produced an explicit blocker reply.
7. If the reply is a blocker, classify it as hard or soft and route the next action immediately.
8. Re-check any worker who gave a blocker reply until they are moving, rerouted, or explicitly released.
9. If nudging fails, move up the intervention ladder: restart, re-plan/reassign, then human escalation only if still unresolved.
10. Convert completed implementation into review gate.
11. Convert completed review into manual execution gate.
12. Hand complete stacks to `land-submodule-stack`.
13. Keep one summary in your own notes of who owns what, which PRs exist, and what gate is still open.

## Do Not

- Do not trust only `bd show` or `gt status` when determining whether someone is working.
- Do not let `gt peek` override direct tmux pane capture.
- Do not treat recent commits, open PRs, or a completed slice as proof that an active epic is progressing.
- Do not infer `active now` from scrollback that only shows prior edits, tests, or reasoning.
- Do not treat successful nudge delivery as proof that a worker resumed work.
- Do not treat a blocker explanation as success if you have not routed the dependency or forced the next action.
- Do not leave ownership ambiguous after a blocker claim.
- Do not stop with an active task still idle if another intervention is available.
- Do not start manual testing before review findings are resolved.
- Do not merge submodule PRs early just because submodule tests pass.
- Do not leave a completed worker idle when another epic or gate needs an owner.
