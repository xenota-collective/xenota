---
name: manage-swarm
description: Coordinate multiple Xenota crew workers and polecats across implementation, review, manual testing, and landing. Use when managing the swarm across crew, dispatching epics across crew, keeping workers unblocked and moving, enforcing opposite-flavor review gates, requiring manual testing plans and manual execution passes, and handing completed feature stacks to the landing workflow.
---

# Manage Swarm

Use this skill when coordinating active work across `xenota` crew and polecats.

## Invocation

This is a skill, not a slash command. Invoke it with a plain-language request in the earthshot Codex pane, for example:

```text
read the manage-swarm skill, then wrangle the swarm
```

If you need to clear the earthshot pane first, use the helper script:

```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/restart_wrangle.sh
```

This helper performs the required `/clear`, separate `Enter`, wait, and re-read sequence. Do not inline this flow in the skill.

When restarting the live XSM manager, use the repo-local launcher:

```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/restart_local_xsm.sh
```

Do not start XSM with `/Users/jv/.local/bin/xsm` or any other global `uv tool` shim. The live manager must run from `xenon/packages/xsm/.venv/bin/xsm` so it uses the checked-out source tree.

Do not run the live manager in any pane other than the one tagged `@xsm_role=runtime` (xc-6tdu2). The launcher resolves the runtime pane by that tmux user option and stamps it on every successful launch, so the runtime survives workmux sidebar visibility toggles that would otherwise shift pane indices. The legacy `xc:0.2` index is kept as a starting hint for first-time runs only; once a pane is tagged, the launcher always finds the same physical pane regardless of layout. Verify the active runtime with:

```bash
tmux list-panes -s -t xc -F '#{pane_id} #{@xsm_role}' | awk '$2=="runtime"{print $1}'
```

For worker-lane resets, use the helper script in this skill:

```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/clear_and_assign.sh <worker> '<instruction>'
```

Use the default `/clear` reset for routine context hygiene. When XSM or live
inspection shows the worker CLI is under fd pressure
(`worker_fd_pressure_threshold`, default 200), force a full pane recycle instead:

```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/clear_and_assign.sh --respawn <worker> '<instruction>'
```

For ordinary worker messages or nudges, use the centralized helper:

```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/send_worker_message.sh <worker> '<message>'
```

These helpers are the only approved worker-message transport. They must route through the checked-out XSM runtime's centralized delivery API and fail closed if delivery cannot be verified. Do not hand-roll `tmux send-keys` for worker assignment, reassignment, `/clear`, or nudge messages.

Do not fake a clear by telling the worker "your context is cleared." The pane must actually receive `/clear` as its own command before the new assignment text is sent, unless fd pressure requires `--respawn`, which kills and relaunches the worker CLI before sending the assignment.

Common operations should be run through the scripts in `scripts/`. The skill should describe policy and sequence, not embed raw shell recipes.

Operator hard rules:
- Raw tmux injection is emergency recovery only. Never use it for normal worker assignment, reassignment, `/clear`, or nudge messages.
- Do not embed raw tmux input commands in swarm assignment or nudge instructions; use `send_worker_message.sh` or `clear_and_assign.sh`.
- Never rely on a send or assume the helper/script submitted the command unless you verified it.
- After every emergency manual injection, immediately verify the effect before making any status claim.
- Valid proof is one of:
  - `pane_current_command` changed to the expected foreground process
  - fresh pane output advanced after the command
  - the command reproduced directly outside tmux and confirmed the failure or success mode
- Scrollback alone is not proof that the current pane is running the desired process.
- Treat these identities as distinct and never mix them:
  - agent name, for example `wrangler`
  - tmux target, for example `xc:4.1`
  - backend worker handle / workmux id
- If an error says `No agent found matching ...`, stop and re-check which identity type the callee expects before retrying.
- For Python package work under `xenon/packages/*`, default to `uv run --project <package> --group dev ...` instead of bare `pytest` or ad hoc `pip` flows.
- If the package imports sibling modules such as `nucleus`, set `PYTHONPATH` explicitly before running commands.
- For the live XSM daemon specifically, prefer the checked-out runtime at `xenon/packages/xsm/.venv/bin/xsm`. Do not assume a global `xsm` binary is current.
- `bd sync` is not a valid beads command. After creating, updating, or closing beads, run `bd dolt push` and verify it reports a successful push.
- Supervisor and landing Codex command allowlists are carried in `.xsm-local/strategies/live-backlog.yaml` under `role_packages.<role>.startup_prompt`. After adding a maintenance command there, restart the role with `scripts/start_supervisor_and_landing.sh` and verify the pane shows bypass permissions plus a successful command run.

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

## Prime directive: you ARE the operator

There is no human-operator role separate from xsm and the supervisor. xsm IS the operator. The supervisor IS the operator. The wrangler (this skill, when run by an in-chat agent) IS the operator. Any worker pane sitting on an operator-input gate (Claude permission dialog, custom-options menu, merge-confirmation prompt, "Type something" Y/N) MUST be resolved in-band by xsm or the supervisor without escalation to a separate human.

A gate sitting unanswered for >1 wrangle pass is **catastrophic system failure**, not "waiting on human." The wrangler's job in that state is twofold: (a) tactically answer the gate so the worker resumes immediately, (b) rebuild the supervisor's prompt with stricter wording, file a system bead, and change the code so the failure cannot recur.

Operator gate resolution policy (xsm/supervisor must apply this in-band):

- **Claude permission dialog** ("Do you want to make this edit to <file>? 1.Yes 2.Yes-and-allow-edit-own-settings 3.No"):
  - If file is on a feature branch and not under `.claude/`: send `1` (Yes).
  - If file is under `.claude/`: send `2` (Yes-and-allow for session) — `--dangerously-skip-permissions` does NOT cover settings edits, and option `2` grants per-session persistence so the same prompt stops recurring.
  - If unclear and reversible: send `1`.
- **Claude/codex custom-options menu about a PR merge** ("1. Approve merge 2. Hold 3. Type something 4. Chat about this"):
  - If `mergeStateStatus=CLEAN` AND CI green AND diff visible AND non-destructive: send `1` (Approve).
  - Otherwise read the visible context and answer based on evidence.
- **Gemini "1. Rewind conversation / 2. Do nothing (esc)" modal**: send Escape twice.
- **Any other gate**: capture the pane scrollback, infer the answer, send the keystroke, verify clear by recapturing.
- **If the gate genuinely requires information not visible in the pane**: file a bd bead with the captured snippet AND assign a different bead to the same worker so they keep moving. Do NOT leave the worker parked.

## Escalation tier philosophy

Keeping workers moving is owned strictly in this order. Each tier is the safety net for the previous one. Don't nudge across tiers — fix the layer where the failure originated.

1. **xsm** owns the autonomous loop. xsm should detect idle lanes and dispatch them. If a lane is `parked_unassigned` with workable beads in `bd ready`, xsm should be assigning, not waiting. A worker that just released a lease via PR handoff is idle, not "in transition" — xsm must reassign.

2. **Supervisor** is the safety net when xsm misses something. The supervisor walks every worker pane (capture-based, not bd-based), reassigns from bd ready, drains leader_inbox, enforces review/manual-test/landing gates. Supervisor is not a passive reporter — if it sees idle workers and unblocked backlog, it MUST dispatch.

3. **Wrangler** (operator chat agent) is the safety net when xsm AND supervisor both fail. The wrangler's first move at this tier is NOT to nudge the supervisor again. It is to find the root cause and change the system at the layer where the failure originated:
   - xsm classifying releases as something other than idle? Patch xsm's classifier.
   - Supervisor's repertoire missing a "walk parked_unassigned" pass? Patch the repertoire.
   - bd ready returning beads the dispatcher rejects on a hidden filter? Patch the filter.

Tactical reassignment is acceptable to unstick the immediate state, but a bead capturing the system-level gap is mandatory in the same wrangle pass.

Two consecutive cycles of nudging at any tier without root-cause work = system failure. Stop nudging, switch into diagnosis mode, file the bead, change the code.

PR-handoff is not idle-rest:
- The moment a worker opens a PR and posts the handoff comment, the lane is `parked_unassigned`.
- xsm owns reassigning that lane (tier 1). The supervisor is the safety net (tier 2).
- The classification "completed via PR handoff; lane returned to pool" is the signal to assign next, not to wait.
- "Leader inbox is drained, gates are clear" is NOT a stop condition while parked_unassigned lanes exist. Walk the lanes.

The only legitimate reasons for a worker to be idle:
1. **Out of work** — bd ready is genuinely empty for that lane's driver/skills.
2. **Token usage limit hit** — the agent's API quota is exhausted (claude usage bar at 100%, codex rate-limited, gemini quota gone).
3. **System failure** — *unrecoverable*: CLI process actually dead, network down, host fd-exhausted. NOT "pane is in a state we don't auto-handle" — that's an xsm classifier gap, not a system failure.

Anything else is a swarm coordination failure. Specifically:
- "PR submitted, awaiting review" is NOT idle. Assign the next bead.
- "Lane parked_unassigned" is NOT idle. Assign the next bead.
- "Supervisor reported no work needed" while parked_unassigned lanes exist is NOT idle. Supervisor was wrong; the wrangler must dispatch.
- "Bead is blocked on operator/admin action" is NOT idle for the *worker*. Pick a different bead. The blocker stays on the bead.
- "Pane is at a TUI modal we don't auto-handle" (gemini "Rewind / Do nothing", claude permission dialog, codex placeholder text) is NOT system failure. It's an xsm classifier gap — see xc-r8bsr. Don't reach for respawn; teach xsm the state and the right response.

TUI modal/gate states fall into three categories that xsm and the supervisor must distinguish:

**Auto-dismiss** (xsm presses the safe key, worker resumes):
- Gemini "● 1. Rewind conversation / 2. Do nothing (esc)" — press Escape.
- Other recoverable transient prompts whose safe answer is unambiguous.

**Operator gate** (xsm escalates to leader_inbox with structured options):
- Claude permission dialog "Do you want to make this edit to <file>? 1.Yes 2.Yes-and-allow 3.No" — operator picks.
- Claude/codex custom-options menus that ask "what should I do next" with non-obvious choices — operator picks.
- Auth prompts, sudo prompts, MFA — operator only.

**Empty-prompt placeholder** (xsm classifies as parked_unassigned eligible for dispatch):
- Codex placeholders: "Summarize recent commits", "Improve documentation in @filename", "Write tests for @filename", "Use /skills to list available skills", "Find and fix a bug in @filename", "Implement {feature}", "Explain this codebase", etc.

If you find a lane in a state that doesn't fit one of these three categories, do NOT classify it as system failure. File a bead targeting xsm's classifier with a captured fixture of the new state, then handle it tactically (auto-dismiss with Escape if safe, or escalate to operator).

Don't reach for respawn or kill as the first remediation. Respawn loses session state and hides the underlying classifier gap. Use respawn only when the CLI process is actually dead.

## P0 Priority Rule

P0 beads take absolute priority over all other work.

During every wrangle pass:
1. Check for open P0 beads with:
   ```bash
   /Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/p0_scan.sh
   ```
2. If any P0 bead exists and has no active worker, immediately assign the most suitable idle crew member to it. If no crew is idle, preempt the lowest-priority active lane.
3. P0 beads skip the normal epic-child sequencing. They do not need to wait for their parent epic's phase ordering.
4. When a P0 bead reaches landing readiness, it jumps the landing queue. The dedicated landing worker should land P0 stacks before any other pending landing.
5. P0 beads that are blocked must be escalated to the human immediately, not parked.

## Worker Driver Discipline

Every worker pane's running CLI MUST match the driver implied by its name. The convention:

- `worker-claude-*` → must run `claude`
- `worker-codex-*` → must run `codex`
- `worker-gemini-*` → must run `gemini`

The expected roster is **2 of each driver** — `worker-claude-1`, `worker-claude-2`, `worker-codex-1`, `worker-codex-2`, `worker-gemini-1`, `worker-gemini-2`. This matches the `driver:` field for each agent in `.xsm-local/swarm-backlog.yaml`. The agent runs in pane `.1` of each worker window.

Why this matters:
- The opposite-flavor review gate depends on knowing what each worker is. A `worker-codex-*` pane running Claude breaks review routing.
- Performance and cost characteristics differ by driver — `worker-gemini-*` running Claude wastes Anthropic quota and skews capacity planning.
- The wrangler's allocation decisions assume the name reflects reality.

How to detect:
1. After every restart of xsm or tmux, list `xc` windows and confirm all 6 `worker-*` windows are present and in the `xc` session (see "Worker Session Discipline" below).
2. Capture pane `.1` of each `worker-*` window.
3. Look at the agent banner: Claude shows `Claude Code v…` and `Opus/Sonnet/Haiku`; Codex shows `gpt-…` and `codex`; Gemini shows `Gemini …` and the gemini banner.
4. If a pane's running CLI does not match its window name, treat it as a driver violation and fix immediately.

How to fix (operator emergency recovery — raw tmux is permitted here):

```bash
# pane .1 of worker-<driver>-N is the agent pane
WP=$(workmux path <worker-handle>)
tmux respawn-pane -k -c "$WP" -t xc:<window>.1 "/bin/zsh -l"
sleep 1
tmux send-keys -t xc:<window>.1 -l '<driver>'
tmux send-keys -t xc:<window>.1 C-m
```

Then re-capture and confirm the correct CLI banner before leaving the lane.

Worktree, branch, and any uncommitted file state are preserved by `respawn-pane`. Only the in-memory CLI session is lost — that is the intended outcome when the wrong CLI was running.

Driver-violation check is part of the default wrangle loop. Add it to the crew pass.

## Worker Session Discipline

Every worker MUST live as a window inside the `xc` tmux session. Workers are never allowed to live in their own separate tmux session.

- expected layout: one `xc` session, with `workmux`, `supervisor`, the six `worker-*` windows, `landing`, `product-owner`, `retro`, `auditor`
- `tmux list-sessions` must show only `xc` (and any user-attached sessions unrelated to the swarm) — there must be no per-worker sessions like ` worker-claude-2`

The `workmux open <handle>` command can silently land a worktree in its own tmux session if that worktree's stored mode is `session` rather than `window`. This has happened in practice and is a violation. Always pass `--mode window` when opening worker worktrees, and verify the result.

Detect after any open/restart:

```bash
tmux list-sessions -F '#{session_id} #{session_name}'
```

If a worker session shows up outside `xc`, fix it by moving the window into `xc` and killing the orphan session:

```bash
sid=$(tmux list-sessions -F '#{session_id} #{session_name}' | grep '<worker-handle>' | awk '{print $1}')
wid=$(tmux list-windows -t "$sid" -F '#{window_id}' | head -1)
tmux move-window -s "$wid" -t xc:
tmux kill-session -t "$sid"
tmux rename-window -t xc:<new-window-index> <worker-handle>
```

After moving, re-verify the pane layout (the standard worker layout has 4 panes: workmux/agent/zsh/zsh) and confirm the agent driver matches the worker name per the rule above.

Preferred path when opening a missing worker:

```bash
workmux open --mode window <worker-handle>
```

Run this from a shell that is already inside `xc` (for example via `tmux send-keys` into `xc:0.*`) so workmux attaches the new window to `xc` rather than creating a fresh session.

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
- Treat lack of movement on an active task as a failure condition requiring intervention, not as a password status outcome.
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
- The current session operator has authority to approve or deny worker blockers, requests, and gates directly.
- The current session operator has authority to approve landing requests directly.
- Do not leave lanes parked on vague approval waits when you can issue the approval yourself in the current session.
- Treat dedicated landing workers as a landing-only pool. If someone is serving as the landing owner for the swarm (for example `last`), do not reallocate them to implementation, review, or manual-test beads.
- If a landing blocker has already been explicitly routed back to an implementation owner, the landing worker must not start branch surgery on that same branch unless ownership is explicitly reassigned. Landing coordination and implementation refresh are separate lanes.
- Landing blockers must be filed through `.claude/skills/manage-swarm/scripts/landing_blocker.sh`. The helper keys on canonical PR `external_ref` values such as `gh:xenota-collective/xenota#229` AND requires label `landing-dirty` or `landing-blocker` to count as an existing blocker; non-blocker beads (feature, audit, pointer-PR) that share the same `external_ref` are ignored. If a non-closed landing-blocker bead already has that ref, the helper appends producer/signal evidence to it instead of creating another bead. After creating a fresh blocker, the helper re-runs the lookup and closes itself as a duplicate if a concurrent producer registered an earlier bead for the same ref. Both `find` and `file` reconcile stale duplicates (close every non-winner) on every invocation, and `find` reports `.reconciled` (count of losers closed) so callers can detect helper writes and push them. The 60-second landing poll skips dirty PRs that already have an open blocker rather than re-commenting evidence, and pushes pending bd writes (created blockers, deduplicated comments, or stale-duplicate cleanups) at end of cycle — retrying the push next cycle if it fails, so a transient `bd dolt push` failure does not strand local-only writes.

Serialized lane-control rule:
- When a lane is stale, nonresponsive, or carrying poisoned context, intervene on that lane alone until it is clearly moving, rerouted, or escalated.
- Do not reset multiple worker panes in parallel.
- Do not send a second assignment to the same lane until you have re-captured the pane and verified what the first reset/assignment did.
- A lane takeover is: capture -> reset with helper script -> send exactly one assignment with exactly one first step -> re-capture -> decide whether the lane is moving or failed.
- If the lane is still at a prompt after one clean takeover attempt, treat that as a failed reset and reroute or escalate. Do not keep stacking fresh text into the pane.

PR handoff rule:
- PR submission is not an idle resting state.
- Once a worker has opened the PR, posted the bead comment, and handed off to the next gate, clear the lane and assign the next bead immediately.
- Do not leave a worker sitting on their old PR branch waiting for review or manual testing results.

Status rubric:
- `active now`: the worker pane shows current execution, active reasoning, or a live gate they are presently driving
- `idle but advanced`: meaningful work was completed earlier, but no one is actively pushing the next slice now
- `assigned only`: the epic has an assignee, hook, branch, or dirty tree, but the pane does not show current motion
- `stalled`: the epic should be moving, has no valid active dependency, and nobody is currently advancing it
- `failed reset`: the wrangler performed one clean reset-and-assign cycle, re-captured the pane, and the lane still sat idle or kept reviving stale context

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
- when assigning NEW work to a crew member (not continuing existing work), always use the `clear_and_assign.sh` helper:
  ```bash
  /Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/clear_and_assign.sh <name> '<new assignment>'
  ```
  This helper enforces centralized `/clear`, centralized assignment delivery, and the ready-prompt wait sequence.
- when a crew member finishes an epic, reaches a real handoff point, or goes idle while still owning an active epic, immediately reassign them or push them onto the next slice
- do not assume a worker will self-chain from a one-off request unless you explicitly told them to keep working through the epic
- if a crew member is the dedicated landing worker, only reassign them onto another landing task; do not spend that lane on implementation follow-up just because they became free

Common helpers:

```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/assign_bead.sh <epic> <name>
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/send_worker_message.sh <name> 'Reply with exact branch name, first bead, next 2 beads, and confirm PR-based landing.'
```

Standing-order nudge pattern:
- state the active epic and current priority clearly
- tell the worker to never stop at a passing test, local summary, or completed micro-slice
- tell the worker to choose and execute the next concrete slice themselves after each completed slice
- do not train the worker to optimize for a rigid reply format instead of execution
- tell the worker not to merge or land anything themselves unless they are the designated landing owner and using the landing formula
- if you assign a landing task, explicitly tell the worker to read the landing skill before acting and to stop for human approval once the branch/PR is merge-ready
- if the worker includes `NEXT` / `BLOCKED`, treat it as optional status metadata, not the main objective

Preferred wording (via helper):

```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/send_worker_message.sh <name> 'Your active assignment is <bead>. Read the start-feature skill FIRST — you must work on a feature branch off origin/main, never push to main. Branch name: <crew>/<bead-id>-<slug>. Start immediately. Never stop at a passing test, summary, or completed micro-slice. After each slice, choose and execute the next concrete slice yourself. When your work is complete, read the prepare-review skill and submit a PR. Do not push to main. Do not merge anything. Only stop at a real blocker or an explicit handoff gate.'
```

Do not use:

```text
nudge_worker.sh ... 'Reply only with NEXT=... BLOCKED=...'
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

Mandatory Helper Commands:

```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/capture_pane.sh <name>
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/capture_polecat.sh <polecat>
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/crew_status.sh <name>
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/lane_snapshot.sh <name>
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/bead_show.sh <bead>
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/polecat_list.sh xenota
```

Manual tmux verification loop:
1. Capture or inspect the pane first
2. Send literal text only
3. Send a separate `C-m`
4. Re-capture immediately
5. Decide which of these states is true:
   - command is now running
   - pane is still at prompt with queued text gone
   - pane rejected the command or returned to shell
6. Do not report "restarted", "running", or "delivered" unless step 5 proved it

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
1. Send the nudge via helper
2. Re-capture the pane via helper and verify motion or an explicit blocker reply
3. If the nudge landed but the pane did not change, escalate: resend with sharper instruction via `clear_and_assign.sh`, or reassign
4. If the worker completes one slice and returns to a prompt without a blocker, treat that as non-compliance with the standing order and intervene again immediately
5. If the human is actively steering the lane from chat, do not keep nudging on top of that unless the worker is clearly stuck and not working

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
   - update the relevant bead ownership via `assign_bead.sh`
   - tell the blocked worker exactly what they should do while waiting, or explicitly release/reassign them
5. A blocker reply without follow-through from the wrangler is not resolution

Weak blocker patterns that require pushback:
- "blocked on another epic" without naming the next useful step available now
- "outside ownership boundary" when prep, tests, review, documentation, or integration harness work can still proceed
- "waiting on landing" without active landing ownership or current landing motion
- "needs another subsystem" without identifying and routing the actual owner

Intervention ladder:
1. `nudge and check`
   - send an exact next action via `send_worker_message.sh`
   - re-capture the pane via `capture_pane.sh` and verify motion or an explicit blocker reply
   - if recent human input is visible in the pane and the worker is not clearly stuck, skip this step and continue observing instead of layering more instructions
2. `reset worker`
   - if the pane is wedged, ignoring input, or stuck in bad modal/editor state
   - use the `clear_and_assign.sh` helper script so `/clear` and the next assignment go through centralized delivery
   - if the worker CLI is over the configured fd threshold, use `clear_and_assign.sh --respawn` so the OS-level process state is reclaimed instead of only clearing context
   - do this serially, one lane at a time
   - if a worker remains a repeat offender across multiple wrangle passes, use the helper reset script once, re-capture, and if the pane still sits idle classify the lane as `failed reset`
   - do NOT kill crew sessions except for fd-pressure respawns or the established emergency recovery path
3. `reconfigure task plan and reassign`
   - if the current owner cannot productively advance the slice
   - break the work into a more concrete next bead, reroute ownership via `assign_bead.sh`, or move the worker to a better-fit slice
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
- If the same crew session repeatedly fails to take reassignment or keeps reviving stale context, use `clear_and_assign.sh` once, then classify the lane as `failed reset` and reroute or escalate instead of repeating the same weak intervention.

Epic classification pass:
1. Read the worker pane via helper
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
wrangle_count: 0  # incremented by rearm_timer.sh after each wrangle pass
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

The example values above are illustrative only. Do not treat `hooked_epic`, branch names, or bead IDs in this schema example as live assignments.

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

- after reporting, re-arm the reminder injector in `xc-crew-earthshot:0.2` via the helper script:
```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/rearm_timer.sh <SECONDS>
```

- the helper script reads `wrangle_count` from `swarm-state.yaml`, increments it, writes the incremented value back, and then decides the reminder mode from the incremented count
- if the incremented `wrangle_count` is divisible by 5, the script arms the timer to send `/clear`, submit `Enter`, wait, then send `read the manage-swarm skill, then wrangle the swarm`
- otherwise it arms the normal `wrangle the swarm` reminder
- do not hand-roll this logic outside the helper unless the script itself is broken
- re-arm is not complete until you re-capture `xc-crew-earthshot:0.2` and verify the pane is operationally clean (clean prompt plus one current timer arm)

### Wrangle count and periodic context reset

The `wrangle_count` field in `swarm-state.yaml` is owned by `rearm_timer.sh`. The helper increments it after each wrangle pass. When the incremented count is divisible by 5, the wrangler must force a context reset before re-arming to prevent drift:

1. Send `/clear` to the earthshot pane to reset context
2. After the clear, send the instruction to re-read the manage-swarm skill and wrangle

This ensures the wrangler periodically re-reads its own skill definition from disk rather than drifting from accumulated context.

Every-5th-pass re-arm pattern:

```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/rearm_timer.sh <SECONDS>
```

Important:
- the helper script is responsible for injecting `/clear` first, sleeping 1, then sending `Enter` as a separate tmux call
- the helper script must never paste `/clear` and the wrangle instruction into the same send operation
- if you bypass the helper and skip the `Enter`, the next injected text will be appended to `/clear` and corrupt the command

## Review Gate

For code-bearing work, require an opposite-flavor review before calling the work done:
- Codex implementation -> Claude polecat review
- Claude implementation -> Codex polecat review

Rules:
- review the full feature branch/PR stack, not just one file
- findings must be posted back on the epic or designated review bead
- if findings exist, send them back to the implementation owner before manual testing

Pattern:
1. Create a dedicated review child bead via `create_review_bead.sh`
2. Dispatch a polecat of the opposite flavor via `sling_review.sh`
3. Require comments on the epic or review bead

Helpers:

```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/create_review_bead.sh <epic> <claude|codex> [P1]
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/sling_review.sh <review-bead> <claude|codex> xenota
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

Helper:

```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/nudge_manual_test_plan.sh <name> <epic>
```

## Manual Execution Gate

Manual execution should be done by a separate worker or polecat, not by the implementer.

Rules:
- execute the plan in practice; do not restate it
- post concrete results, commands run, pass/fail, and deviations
- clearly separate executed coverage from later integration gaps
- verify the results are actually posted on the parent epic or designated manual-test bead before allowing landing to proceed

If the epic is already hooked to a review worker, create a child bead for manual execution and dispatch that instead of re-hooking the epic.

Helpers:

```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/create_manual_test_bead.sh <epic> [P1]
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/sling_manual_test.sh <manual-test-bead> <claude|codex> xenota
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
- landing workers must get explicit approval in the current session before running any merge command or taking any action that actually lands the branch/PR
- the current session operator may grant that approval directly; do not wait for a separate human if the current session already authorized landing decisions
- readiness to merge is a stop-and-approve gate, not implicit permission to merge
- P0 stacks jump the landing queue. If both a P0 and a P1 stack are ready to land, the landing worker must take the P0 first. If the landing worker is mid-flight on a non-P0 landing and a P0 becomes landing-ready, finish the current landing then immediately take the P0 next.

Current landing formula:
- `land-submodule-stack`

Helper:

```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/sling_landing.sh <epic> <landing-agent> codex xenon '<list>'
```

## Reassignment Rule

If a crew member finishes or reaches a real wait-state:
- reassign them immediately
- if the old context is heavy, clear/restart the session first via `clear_and_assign.sh`

Session reset pattern:

Do NOT kill crew sessions. Instead, use the helper reset script to reset context within the running session:

```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/clear_and_assign.sh <name> '<new assignment>'
```

Do not send text like "your old context is cleared" as a substitute for the actual clear. The script sends `/clear`, submits it via separate `Enter`, waits, and only then injects the new assignment.

Dedicated landing-worker reassignment rule:
- when the dedicated landing worker becomes free, first use `clear_and_assign.sh` so stale implementation context does not leak into the next landing task
- then assign only the next landing-owned bead/epic that is actually at a landing or landing-readiness gate
- in the handoff message, explicitly instruct the worker to read and follow the landing skill / landing formula for the new task
- in the handoff message, explicitly instruct the worker that they must stop and request human approval once the branch/PR is ready to merge

Landing-worker handoff pattern (via helper):

```bash
/Users/jv/gt/xenota/crew/earthshot/.claude/skills/manage-swarm/scripts/clear_and_assign.sh <name> 'Your new active assignment is <landing-bead>. This is a landing task. Read the landing skill / landing formula before taking any landing action. Start immediately and use that formula for this task. Do not switch into implementation or review work unless a real landing blocker forces an explicit reroute. Do not merge on your own authority. When the branch/PR is ready, stop and ask the human for approval before merging.'
```

Required landing handoff wording elements:
- "Read the landing skill before you take any landing action"
- "Do not merge on your own authority"
- "When the branch/PR is ready, stop and ask the human for approval before merging"

For Claude sessions that may be in vim mode:
- always use `clear_and_assign.sh` instead of trying to recover the pane manually
- if the pane still stays at a prompt without consuming the instruction, classify it as `failed reset` and reroute or escalate

## Work Priority Order

Every allocation decision — whether assigning idle crew, preempting, or choosing the next slice — follows this strict priority cascade:

1. **P0 beads** — absolute top priority, any open or in-progress P0 regardless of parent epic
2. **Assigned epic children** — any workable bead within the currently hooked/assigned epic and its full child tree, ordered by priority within that tree
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

1. **P0 scan**: Check for any open or in-progress P0 beads with `scripts/p0_scan.sh`. If any exist without an active worker, they take priority over everything below. Assign immediately, preempting lower-priority lanes if needed.
2. **Bead pass**: List all children of the hooked epic via `scripts/bead_show.sh`. For each non-closed bead, check status, assignee, PR state, and classify.
3. **Crew pass**: For each crew member, capture pane via `scripts/capture_pane.sh`, check hook via `scripts/crew_status.sh`, branch, and classify. Identify idle crew.
4. **Idle crew reallocation**: For each idle crew member, walk the Work Priority Order top to bottom. Assign the first workable bead found via `scripts/clear_and_assign.sh`. If no workable bead exists at any tier, escalate to the human immediately — do not leave the crew member parked.
5. **Gate pass**: Check active review/manual-test/landing polecats and active gate owners via `scripts/polecat_list.sh` and `scripts/crew_status.sh`.
6. **Active-bead verification**: For each active bead, verify there is a worker actively moving it now or an explicit active dependency via `scripts/lane_snapshot.sh`.
7. **Take over stale lanes serially**: For each stale lane, run the serialized lane takeover flow one lane at a time: capture -> reset with `scripts/clear_and_assign.sh` -> one assignment with one first step -> re-capture -> classify moving vs `failed reset`.
8. **Blocker routing**: If the reply is a blocker, classify it as hard or soft and route the next action immediately.
9. **Gate conversion**: Convert completed implementation into review via `scripts/create_review_bead.sh` and `scripts/sling_review.sh`, completed review into manual execution via `scripts/create_manual_test_bead.sh` and `scripts/sling_manual_test.sh`, and completed gated stacks into landing handoff via `scripts/sling_landing.sh`.
10. **Landing handoff**: Hand complete stacks to `land-submodule-stack` and do not allow any other landing path.
11. **State write**: Read previous `swarm-state.yaml`, build new state, write the updated state file, and output only the changes (transitions, new blockers, idle crew, PR state changes, ready-for-landing). If first run, write `wrangle_count: 0`; the re-arm helper will increment it.
12. **Reminder re-arm**: Run `scripts/rearm_timer.sh <SECONDS>`. The helper increments `wrangle_count`, then checks whether the incremented count is divisible by 5 and chooses the every-5th-pass re-arm pattern or the normal pattern accordingly.

## Do Not

- Do not trust only `bd show` or `gt status` when determining whether someone is working.
- Do not let `gt peek` override direct tmux pane capture.
- Do not treat recent commits, open PRs, or a completed slice as proof that an active epic is progressing.
- Do not infer `active now` from scrollback that only shows prior edits, tests, or reasoning.
- Do not treat successful nudge delivery as proof that a worker resumed work.
- Do not treat a blocker explanation as success if you have not routed the dependency or forced the next action.
- Do not leave ownership ambiguity after a blocker claim.
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
