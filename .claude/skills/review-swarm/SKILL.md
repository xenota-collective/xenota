---
name: review-swarm
description: Read-only status review of the live XSM swarm. Checks xsm daemon pane + logs, each worker pane, the swarm-backlog config, the bead backlog, and open PRs across xenota + xenon. Use when the operator asks "what's the swarm doing", "why is xsm idle", "status", or when starting a wrangle session and you need to orient.
---

# Review Swarm

Fast, read-only reconnaissance. This skill does NOT mutate state (no `/clear`, no nudges, no kills). If the review uncovers a problem that needs action, hand off to `manage-swarm` or surface a diagnosis to the operator.

## Step 1: Collect data

Run the collection script. It gathers all signals in one pass:

```bash
/Users/jv/projects/xenota/.agents/skills/review-swarm/scripts/collect_swarm_status.sh /Users/jv/projects/xenota
```

The script outputs labelled sections for: xsm process, daemon pane, latest wrangle run, non-noop events, leader escalations, repetition check, worker panes, swarm-backlog.yaml, xr smoke check, bd beads, and open PRs.

## Step 2: Interpret the data

Read the full script output, then produce a tight report using only these judgment calls:

### XSM daemon status

From the `XSM PROCESS` and `XSM DAEMON PANE` sections, classify:
- **running**: last pane line is a JSON wrangle event with incrementing `wrangle_count`.
- **aborted**: pane shows `^C`, `Aborted!`, or a shell prompt.
- **hung**: same `wrangle_count` seen in two consecutive events, or codex process running >30min without xsm parent.

### Worker state summary

From `WORKER PANE SNAPSHOTS`, read each worker's last 30 lines and classify one line per worker:
- State: `active_working | blocked_declared | parked_handoff | parked_unassigned | stopped`
- Current bead (look for bead ID in pane text, e.g. `xc-XXXX`)
- One-line description of what the pane shows (last tool call, blocker text, idle prompt)

If a pane shows `Blocker: HARD` or `Human approval needed` the worker is correctly escalating, not stuck.

### Repetition check

From `RESET_AND_ASSIGN REPETITION CHECK`, any agent+bead with count >= 3 is unproductive wrangling. Flag it.

### Backlog divergence

From `BEAD BACKLOG` and `SWARM-BACKLOG.YAML`, compare:
- Beads the yaml lists that `bd` has already closed → stale config entries.
- Open high-priority beads in `bd` that the yaml hasn't picked up → missed dispatch.

### PR cross-reference

From the `OPEN PRs` sections:
- PRs authored by workers that are CLEAN + green but unmerged → blocked on human, match to worker `blocked_declared` states.
- Dependabot PRs → count them, they relate to bead `xc-o7f3`.
- PRs with `CONFLICTING` → worker needs to rebase.

## Step 3: Emit the report

Target ~20 lines. No raw pane dumps.

```
XSM: <running|aborted|hung> run=<short-run-id> pass=<N>
Last action: <from events or leader-backlog tail>

Workers:
  worker-claude-1  <state>  <bead>  <one-line context>
  worker-claude-2  <state>  <bead>  <one-line context>
  worker-codex-1   <state>  <bead>  <one-line context>
  wrangler         <state>  <bead>  <one-line context>

Backlog: <N open beads>, top: <bead-id> P<n> <title>
Open PRs xenota: <N> (<blocked-on-human>)
Open PRs xenon:  <N> (<blocked-on-human>, <dependabot>)

Flags:
  - <concrete issue or "none">
```

## What to flag

- **Unproductive wrangling**: same agent+bead `reset_and_assign`'d 3+ times. Refer to `manage-swarm`, don't fix here.
- **Dead daemon + live workers**: xsm aborted but workers have active panes. "XSM down, X workers still running."
- **Branch/lease mismatch**: worker on branch that doesn't match its bead assignment.
- **All workers blocked on human**: healthy-but-parked. "Waiting on operator for PR #N, #M." Do not escalate.

## What NOT to do

- Do not send keys to any pane. Read-only.
- Do not kill xsm. Surface it and ask the operator.
- Do not modify `swarm-backlog.yaml` or bead states.
- Do not close PRs or comment on them.
- Do not run `xsm wrangle --once` — it writes events and could interfere with the daemon.
