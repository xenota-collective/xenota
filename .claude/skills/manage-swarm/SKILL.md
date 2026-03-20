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

## P0 Priority Rule

P0 beads take absolute priority over all other work.

During every wrangle pass:
1. Check for open P0 beads: `bd list -p P0 -s open --flat` and `bd list -p P0 -s in_progress --flat`
2. If any P0 bead exists and has no active worker, immediately assign the most suitable idle crew member to it. If no crew is idle, preempt the lowest-priority active lane.
3. P0 beads skip the normal epic-child sequencing. They do not need to wait for their parent epic's phase ordering.
4. When a P0 bead reaches landing readiness, it jumps the landing queue. The dedicated landing worker should land P0 stacks before any other pending landing.
5. P0 beads that are blocked must be escalated to the human immediately, not parked.

## Branch and PR Discipline

Workers MUST use feature branches and PRs. Direct pushes to main are a policy violation.

Related skills that workers must follow:
- **start-feature**: How to begin work — branch naming, rebase off origin/main, bead hygiene
- **prepare-review**: How to submit work — rebase, test, create PR with bead reference

Every nudge assigning new work must tell the worker to read start-feature first. Every nudge about completed work must tell the worker to read prepare-review.

If you detect a worker has pushed directly to main (check with `git log --oneline origin/main -5 --format='%h %an | %s'`), immediately:
1. Flag it as a violation in the wrangle output
2. Nudge the worker to stop and read start-feature
3. Escalate to the human if it keeps happening

## Core Rules

- Prefer direct evidence from live tmux panes over bead status when checking whether someone is actually working.
- Use direct tmux pane capture as the primary evidence source. `gt peek`, hook state, dirty branches, recent commits, and bead metadata are corroboration only.
- An active epic is only progressing if someone is actively working on it now, or it is explicitly waiting on another active worker or gate.
- A completed slice with nobody actively pushing the next slice does not count as progress.
- If a worker is idle at a handoff point and still owns the active epic, nudge them directly onto the next slice.
- After sending a nudge, verify that it changed the pane state. A delivered nudge is not progress until the worker visibly resumes motion or explicitly replies with a blocker.
- The wrangler's job is to restore motion, not merely report status. Do not stop at naming the problem if you can push the next action, route the dependency, or reassign the owner yourself.
- Treat lack of movement on an active task as a failure condition requiring intervention, not as a passive status outcome.
- Treat crew workers as prone to one-shot request/response behavior. Assume they will often complete one asked-for slice and then park unless given a standing order to self-chain.
- Default to standing-order nudges, not single-slice nudges. Require the worker to keep choosing and executing the next concrete slice on the same epic until they hit a real blocker or explicit handoff gate.
- Every wrangle pass must end by re-arming the local reminder injector so `wrangle the swarm` is sent back into the earthshot pane after a delay. This is part of the wrangle loop, not an optional convenience.
- The reminder delay should be dynamic, not fixed. Speed up when many lanes needed intervention; slow down when the swarm is already flowing without help.
- If a Claude pane is over 20% context used, compact it during the wrangle pass before leaving the lane unattended.
- Do not compact Codex panes just because they exist or are active.
- Outside the Claude-over-20% rule, compact only when a session is explicitly handing off work or starting a new task and needs context cleanup.
- If a worker is moving, do not interrupt just to restate bead status.
- If a worker is blocked by tracker noise or Dolt config but git/code work can continue, tell them to keep going.
- If a worker is blocked by another person or unresolved review findings, make that explicit and route the dependency.
- If the pane shows recent direct human input from the current chat session, treat that as a strong coordination signal: do not aggressively reallocate, redirect, or pile on messages just because the lane is momentarily paused.
- When the human is present in the chat, only send a worker message if the worker is actually stuck and not working. Human-steered lanes should default to observation and minimal interference.
- Never try to land work ad hoc. Every landing must go through the landing formula.
- Never treat a worker handoff as merge authorization. Landing workers must still read the landing skill and wait for explicit human approval before any merge.
- Treat dedicated landing workers as a landing-only pool. If someone is serving as the landing owner for the swarm (for example `last`), do not reallocate them to implementation, review, or manual-test beads.
- If a landing blocker has already been explicitly routed back to an implementation owner, the landing worker must not start branch surgery on that same branch unless ownership is explicitly reassigned. Landing coordination and implementation refresh are separate lanes.

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
- do not assume a worker will self-chain from a one-off request unless you explicitly told them to keep working through the epic
- if a crew member is the dedicated landing worker, only reassign them onto another landing task; do not spend that lane on implementation follow-up just because they became free

Suggested commands:

```bash
cd /Users/jv/gt/xenota/mayor/rig
bd update <epic> -a xenota/crew/<name>

gt nudge xenota/crew/<name> --mode immediate --message 'Reply with exact branch name, first bead, next 2 beads, and confirm PR-based landing.'
```

Standing-order nudge pattern:
- state the active epic and current priority clearly
- tell the worker to never stop at a passing test, local summary, or completed micro-slice
- tell the worker to choose and execute the next concrete slice themselves after each completed slice
- do not train the worker to optimize for a rigid reply format instead of execution
- tell the worker not to merge or land anything themselves unless they are the designated landing owner and using the landing formula
- if you assign a landing task, explicitly tell the worker to read the landing skill before acting and to stop for human approval once the branch/PR is merge-ready
- if the worker includes `NEXT` / `BLOCKED`, treat it as optional status metadata, not the main objective

Preferred wording:

```bash
gt nudge xenota/crew/<name> --mode immediate --message 'Your active assignment is <bead>. Read the start-feature skill FIRST — you must work on a feature branch off origin/main, never push to main. Branch name: <crew>/<bead-id>-<slug>. Start immediately. Never stop at a passing test, summary, or completed micro-slice. After each slice, choose and execute the next concrete slice yourself. When your work is complete, read the prepare-review skill and submit a PR. Do not push to main. Do not merge anything. Only stop at a real blocker or an explicit handoff gate.'
```

Do not use:

```bash
gt nudge ... 'Reply only with NEXT=... BLOCKED=...'
```

Why this is harmful:
- it encourages the worker to emit a tidy status line and then park
- it turns `NEXT` into a planning ritual instead of actual execution
- it creates false confidence because `BLOCKED=none` often appears right before the worker stops

Better alternative:
- tell the worker to continue executing by default
- if you need a status tuple, ask for it only at a checkpoint, not as the standing contract
- for active implementation, the default should be action, not reply formatting

## Check-Ins

Default check-in order:
1. Capture the worker tmux pane directly
2. Capture the active polecat pane if there is a gate in progress
3. Check for recent command/output motion in the pane
4. If the pane is a Claude session and context usage is over 20%, compact it before walking away from the lane
5. Do not compact Codex panes here; only compact them at handoff/new-task boundaries if the context reset is actually needed
5. Only then look at hook, branch, bead, and PR state for corroboration

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
- recent human-authored prompts or instructions in the pane = be conservative; prefer letting that guidance play out before sending more messages or reallocating the lane

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
- exception: if the pane shows current-session human steering and the worker has not yet had a fair chance to act on it, do not treat the lane as intervention-ready just because it is briefly idle

Post-nudge verification:
1. Send the nudge with a standing order plus the exact next action and required reply shape
2. Re-capture the pane after delivery
3. Verify one of:
   - the pane shows new live motion on the requested slice
   - the worker replies with a real blocker or explicit handoff gate
4. If the pane is still sitting at a prompt with no new motion, do not mark the epic as moving
5. If the nudge landed but the pane did not change, escalate: resend with sharper instruction, use Escape-first tmux injection, or restart/reassign
6. If the worker completes one slice and returns to a prompt without a blocker, treat that as non-compliance with the standing order and intervene again immediately
7. If the human is actively steering the lane from chat, do not keep nudging on top of that unless the worker is clearly stuck and not working

Session family map for this swarm:
- Claude panes are the ones whose tmux title explicitly shows `Claude Code` (for example `xc-crew-earthshot:0.1`)
- Codex panes in this rig usually show `node` as the pane command (for example `xc-crew-harbor:0.0`, `xc-crew-life:0.0`, `xc-crew-starshot:0.0`, `xc-crew-prosperity:0.0`, `xc-crew-quay:0.0`, `xc-crew-last:0.0`, `xc-crew-earthshot:0.0`)
- Helper shell/timer panes usually show `zsh` or `sleep` and are neither Claude nor Codex worker panes

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
   - if recent human input is visible in the pane and the worker is not clearly stuck, skip this step and continue observing instead of layering more instructions
2. `reset worker`
   - if the pane is wedged, ignoring input, or stuck in bad modal/editor state
   - use Escape-first injection first for Claude panes, then `/clear` if still dead
   - if a worker remains a repeat offender across multiple wrangle passes, `/clear` the session and re-nudge with a fresh standing order rather than preserving poisoned long-lived context
   - do NOT kill crew sessions — use `/clear` to reset context within the running session
3. `reconfigure task plan and reassign`
   - if the current owner cannot productively advance the slice
   - break the work into a more concrete next bead, reroute ownership, or move the worker to a better-fit slice
   - do not jump to reassignment while the current human is visibly steering the worker unless the lane is truly stuck and non-productive
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
- Do not accept "completed one requested slice" as sufficient if the epic still has obvious next work and no real blocker.
- If the same crew session repeatedly fails to take reassignment or keeps reviving stale context, `/clear` and re-nudge with explicit fresh instructions instead of repeating the same weak intervention.

Epic classification pass:
1. Read the worker pane
2. Decide whether the pane is currently at a prompt or in live motion
3. Classify the epic as `active now`, `idle but advanced`, `assigned only`, or `stalled`
4. Record any explicit dependency or gate keeping it from moving
5. If the worker is idle and still owns the active epic, push them to the next slice immediately
6. If the worker answers with a blocker, decide hard vs soft blocker and act on it yourself until ownership and next action are explicit

## Swarm State File

The wrangler maintains a persistent state file at `swarm-state.yaml` in the earthshot repo.

This file is the single source of truth for the swarm's last-known state. It is updated at the end of every wrangle pass.

### State file schema

```yaml
updated_at: "2026-03-20T09:15:00+13:00"
hooked_epic: xc-ds1y
p0_beads: []  # list of {id, title, assigned_to, status}

beads:
  - id: xc-wc20
    title: "Nucleus snapshots, diff, and restore"
    status: in_progress
    assigned_to: xenota/crew/life
    pr_state: "xenon#17 CONFLICT, xenota#9 none"
    classification: active now
    next_action: "rebase onto main, resolve conflicts"

crew:
  - name: life
    agent: codex
    hooked_bead: xc-wc20
    branch: feature/xc-wc20-nucleus-snapshots-clean
    classification: active now
  - name: prosperity
    agent: codex
    hooked_bead: none
    branch: main
    classification: idle
    recommended_assignment: "xc-c77i (P0 dependabot setup)"

ready_for_landing:
  - id: xc-ds1y.2
    title: "Support Gemini as RPT backend"
    gate: "human review"
```

### Reading and writing the state file

At the start of each wrangle pass:
1. Read `swarm-state.yaml` if it exists. This is the previous state.
2. Gather fresh evidence (panes, beads, PRs, hooks, branches).
3. Build the new state.
4. Compare new state against previous state to find changes.
5. Write the updated state back to `swarm-state.yaml`.

### Wrangle output: changes only

Do not print the full state every wrangle pass. Instead, report only what changed since the last pass:

- **Transitions**: beads or crew that changed classification (e.g. `active now` -> `stalled`)
- **New assignments**: crew members that got assigned or reassigned
- **New blockers**: beads that became blocked or stalled
- **PR state changes**: PRs that gained/lost conflicts, CI passed/failed, or were merged
- **Landed / closed**: beads that moved to closed or landed since last pass
- **P0 alerts**: any P0 bead that appeared, changed state, or needs attention
- **Idle crew**: crew members that became idle with recommended next assignment
- **Ready for landing**: beads newly reaching landing readiness

If nothing changed, say "no changes" and move on.

If the state file does not exist (first wrangle), write the file but still only output a brief summary (crew count, active beads, idle crew, P0s, ready-for-landing). Do not dump the full YAML to the user.

### Wrangle output format

Keep wrangle output to a few lines. Example:

```
wrangle: 2 transitions, 1 idle crew reassigned, 1 P0 alert
- starshot: idle -> active now (xc-ds1y.1.3)
- prosperity: idle, assigned to xc-c77i (P0)
- ready for landing: xc-ds1y.2 (human review)
```

The full state lives in `swarm-state.yaml`. The user can read it directly if they want detail. The wrangle output is a changelog, not a report.

### Ready for landing

- always mention ready-for-landing beads in wrangle output, even if unchanged
- one line each: bead ID, title, gate status

### Reminder re-arm

- after reporting, re-arm the reminder injector in `xc-crew-earthshot:0.2`
- prefer the live tmux shell-pane timer over detached background children
- treat the timer pane as an operational surface, not just a command sink
- choose the reminder delay from the current wrangle result:
  - `20s` if 3+ active lanes needed kicks/reassignment/restart
  - `30s` if 2 active lanes needed intervention
  - `45s` if 1 active lane needed intervention
  - `60s` if no intervention needed
- count only real interventions, not metadata updates

Reminder re-arm pattern:

```bash
tmux send-keys -t xc-crew-earthshot:0.2 'sleep <SECONDS>; /opt/homebrew/bin/tmux -L gt send-keys -t xc-crew-earthshot:0.0 "wrangle the swarm"; sleep 1; /opt/homebrew/bin/tmux -L gt send-keys -t xc-crew-earthshot:0.0 Enter' C-m
```

Timer pane hygiene:

- before re-arming, stop any currently running timer in the pane with `Ctrl-C`
- if the pane still shows stacked old timer commands or noisy shell output, clean it before re-arming:

```bash
tmux send-keys -t xc-crew-earthshot:0.2 C-c
tmux clear-history -t xc-crew-earthshot:0.2
tmux send-keys -t xc-crew-earthshot:0.2 'clear' Enter
```

- then inject exactly one fresh timer arm with the reminder re-arm pattern above

Post-arm verification:

- re-arm is not complete until you re-capture `xc-crew-earthshot:0.2` and verify the pane is operationally clean
- acceptable outcomes:
  - a clean prompt plus one current timer arm
  - a clearly running timer command with no stacked stale arms above it
- unacceptable outcomes:
  - multiple old `sleep ... tmux send-keys ...` arms still visible in the active viewport
  - visibly dirty pane state where it is unclear which arm is current
- if the pane is still dirty after the first arm attempt, do not claim success; repeat the hygiene sequence and re-arm once more
- if it still remains visually dirty, report the re-arm as unverified instead of pretending it succeeded

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
Do not merge, close, or call work landed outside the landing formula.

For submodule-backed features:
- use the `land-submodule-stack` formula
- keep submodule PRs and the top-level pointer PR as one coordinated landing unit
- delay submodule merges until the top-level PR is integration-tested and ready to merge

Landing rule:
- if a stack is ready to land, hand it to the landing formula
- if manual QA or another gate is still pending, hold the stack at that gate and do not merge anything
- if someone starts landing work outside the formula, intervene immediately and redirect them onto the formula path
- do not close the parent epic as landed until the formula-run landing is complete
- if you clear a dedicated landing worker off a finished or blocked landing task, immediately route them to the next landing task, not to general implementation work
- when handing a new landing task to a dedicated landing worker, tell them explicitly to read the landing skill / landing formula before acting on that task rather than improvising or switching back into implementation mode
- landing workers must get explicit human approval in the current session before running any merge command or taking any action that actually lands the branch/PR
- readiness to merge is a stop-and-escalate gate, not implicit permission to merge
- P0 stacks jump the landing queue. If both a P0 and a P1 stack are ready to land, the landing worker must take the P0 first. If the landing worker is mid-flight on a non-P0 landing and a P0 becomes landing-ready, finish the current landing then immediately take the P0 next.

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

Do NOT kill crew sessions. Instead, use `/clear` to reset context within the running session:

```bash
tmux send-keys -t xc-crew-<name>:0.0 '/clear' Enter
```

Then nudge the cleared session with the new assignment.

Dedicated landing-worker reassignment rule:
- when the dedicated landing worker becomes free, first `/clear` the session so stale implementation context does not leak into the next landing task
- then assign only the next landing-owned bead/epic that is actually at a landing or landing-readiness gate
- in the handoff message, explicitly instruct the worker to read and follow the landing skill / landing formula for the new task
- in the handoff message, explicitly instruct the worker that they must stop and request human approval once the branch/PR is ready to merge

Landing-worker handoff pattern:

```bash
tmux send-keys -t xc-crew-<name>:0.0 '/clear' Enter
gt nudge xenota/crew/<name> --mode immediate --message 'Your new active assignment is <landing-bead>. This is a landing task. Read the landing skill / landing formula before taking any landing action. Start immediately and use that formula for this task. Do not switch into implementation or review work unless a real landing blocker forces an explicit reroute. Do not merge on your own authority. When the branch/PR is ready, stop and ask the human for approval before merging.'
```

Required landing handoff wording elements:
- "Read the landing skill before you take any landing action"
- "Do not merge on your own authority"
- "When the branch/PR is ready, stop and ask the human for approval before merging"

For Claude sessions that may be in vim mode:
- try the `Escape`-first tmux pattern before `/clear`
- if the pane still stays at a prompt without consuming the instruction, `/clear` and re-nudge immediately

## Work Priority Order

Every allocation decision — whether assigning idle crew, preempting, or choosing the next slice — follows this strict priority cascade:

1. **P0 beads** — absolute top priority, any open or in-progress P0 regardless of parent epic
2. **Assigned epic children** — any workable bead within the earthshot-assigned epic (currently xc-ds1y) and its full child tree, ordered by priority within that tree
3. **Standalone P1 beads** — any P1 bead that is not a child of the assigned epic (e.g. standalone tasks, bugs, follow-ups)
4. **Other P1 epics and their children** — P1 epics outside the assigned epic tree, pick the most advanced or unblocked child
5. **P2 and below** — only when all of the above are either fully staffed or blocked

An idle crew member is a failure state. The wrangler must always assign work from the highest available tier. If there is genuinely no workable bead at any tier — no open P0s, no unworked children of the assigned epic, no standalone P1s, no other P1 epic children — then the wrangler MUST escalate loudly to the human:

```
ESCALATION: {N} crew members idle with no workable beads.
The backlog is empty or fully blocked. Human must scope new work,
create beads, or unblock gates before capacity is wasted.
Idle crew: {list names}
```

Do not silently accept idle workers. Do not park them on research or cleanup unless explicitly told to by the human. Unused capacity is wasted money.

## Default Manage-Swarm Loop

1. **P0 scan**: Check for any open or in-progress P0 beads (`bd list -p P0 -s open --flat` and `bd list -p P0 -s in_progress --flat`). If any exist without an active worker, they take priority over everything below. Assign immediately, preempting lower-priority lanes if needed.
2. **Bead pass**: List all children of the hooked epic. For each non-closed bead, check status, assignee, PR state, and classify.
3. **Crew pass**: For each crew member, capture pane, check hook, branch, and classify. Identify idle crew.
4. **Idle crew reallocation**: For each idle crew member, walk the Work Priority Order top to bottom. Assign the first workable bead found. If no workable bead exists at any tier, escalate to the human immediately — do not leave the crew member parked.
4. Check active gate polecats.
5. For each active bead, verify there is a worker actively moving it now or an explicit active dependency.
6. Nudge idle owners onto the next slice immediately.
7. Verify the nudge changed pane state or produced an explicit blocker reply.
8. If the reply is a blocker, classify it as hard or soft and route the next action immediately.
9. Re-check any worker who gave a blocker reply until they are moving, rerouted, or explicitly released.
10. If nudging fails, move up the intervention ladder: restart, re-plan/reassign, then human escalation only if still unresolved.
11. Convert completed implementation into review gate.
12. Convert completed review into manual execution gate.
13. Hand complete stacks to `land-submodule-stack` and do not allow any other landing path.
14. Read previous `swarm-state.yaml`, build new state, write updated file, and output only the changes (transitions, new blockers, idle crew, PR state changes, ready-for-landing). If first run, output full state.

## Do Not

- Do not trust only `bd show` or `gt status` when determining whether someone is working.
- Do not let `gt peek` override direct tmux pane capture.
- Do not treat recent commits, open PRs, or a completed slice as proof that an active epic is progressing.
- Do not infer `active now` from scrollback that only shows prior edits, tests, or reasoning.
- Do not treat successful nudge delivery as proof that a worker resumed work.
- Do not treat a blocker explanation as success if you have not routed the dependency or forced the next action.
- Do not leave ownership ambiguous after a blocker claim.
- Do not stop with an active task still idle if another intervention is available.
- Do not send only micro-slice nudges when the real need is a standing order to keep chaining work on the same epic.
- Do not start manual testing before review findings are resolved.
- Do not merge submodule PRs early just because submodule tests pass.
- Do not merge, close, or describe work as landed unless it went through the landing formula.
- Do not leave a completed worker idle when another epic or gate needs an owner.
- Do not reallocate the dedicated landing worker onto non-landing work just because they are free.
- Do not silently accept idle crew. If a worker has no bead, walk the Work Priority Order and assign one. If the backlog is genuinely empty, escalate loudly to the human.
- Do not skip priority tiers. P0 first, then assigned epic children, then standalone P1s, then other P1 epics. Never assign P2 work while P1 work is available.
- Do not park idle workers on vague research or cleanup to avoid escalation. If there is no scoped bead, tell the human to scope more work.
