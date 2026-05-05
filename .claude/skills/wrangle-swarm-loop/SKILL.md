---
name: wrangle-swarm-loop
description: Install a recurring 5-minute /loop that wrangles the XSM swarm with mandatory deep root-cause analysis on every idle worker. Use when asked to set up the wrangle loop, start a continuous swarm wrangler, run the swarm wrangler on a schedule, or keep wrangling automatically. Each tick treats any idle worker as a critical xsm-and-supervisor double failure that requires a P0 systemic-fix bead, drains the landing queue, and bumps the xenota pointer + restarts xsm when enough xenon PRs have landed.
---

# Wrangle Swarm Loop

This skill installs a `/loop 5m` cadence that runs the wrangle prompt below on every tick. Use it when the operator wants continuous, RCA-first wrangling of the live XSM swarm — not a one-off pass.

The handbook escalation tier philosophy is the load-bearing principle (see `manage-swarm` and `handbook/docs/plans/technical/xsm-swarm-principles.md`):

- **xsm** owns the autonomous loop and dispatch.
- **Supervisor** is the safety net when xsm misses.
- **Wrangler** (this loop) is the safety net when both fail.

So when this loop sees an idle worker, both prior tiers have already failed. The right response is a **systemic fix**, not another nudge. Two consecutive ticks with the same idle pattern = the system is broken at a layer not yet patched. Stop nudging, file the bead, change the code.

## When to invoke

The operator says any of:

- "set up the wrangle loop"
- "start the swarm wrangler loop"
- "run the wrangle loop every 5 minutes"
- "keep wrangling the swarm"

Do **not** invoke for one-off swarm checks — use `review-swarm` (read-only) or `manage-swarm` (single intervention pass) for those.

## How it works

Invoke the `loop` skill with the 5-minute interval and the wrangle prompt below verbatim. Equivalent to typing into chat:

```
/loop 5m <full wrangle prompt>
```

Use the prompt **exactly as written** — its wording carries the policy gates (RCA-first, P0 bead mandatory, no double-nudge, etc.). Do not paraphrase.

## The wrangle prompt (use verbatim)

```
Wrangle the XSM swarm. This is a 5-minute tick — do not rush, do not skip RCA.

PRINCIPLE: any worker pane that is idle right now is evidence of TWO upstream failures stacked on top of each other:
  (a) xsm failed to autonomously reassign the lane after handoff, AND
  (b) supervisor patrol failed to catch the gap and dispatch from bd ready.
Both are critical, swarm-degrading bugs. The right response is a SYSTEMIC FIX, not another nudge.

STEP 0 — Goal-state check + perf-pathology scan (before anything else).
  Answer in one sentence: "is at least one configured worker currently executing a backlog bead?" Look at pane motion, not just bd state. If the answer is NO, that is the only signal that matters this tick — PR throughput, beads filed, agents spawned do not count as progress.
  Then run /Users/jv/projects/xenota/.claude/skills/manage-swarm/scripts/loop_no_op_guard.sh — it scans recent wrangle-runs for pathological signals (no_op_streak, observation_budget_exhaustion, identical_idle_pattern). If it returns rc=2 (KILL), stop the loop now (CronDelete or /loop stop) and message the operator with the script's summary plus 2-3 options. If rc=1 (WARN — pathological metric repeating), STOP shipping side fixes; file/update a P0 bead for that exact metric and either fix it or escalate. Do NOT layer adjacent fixes onto a broken pipeline.
  ALSO: only proceed if at most one dev-coder agent is currently in flight for this loop. Two parallel fixes against an unstable substrate is speculation; check via TaskList before dispatching another.

STEP 1 — Read state, do not mutate.
  Run /Users/jv/projects/xenota/.agents/skills/review-swarm/scripts/collect_swarm_status.sh /Users/jv/projects/xenota
  Capture every worker pane, the supervisor pane, and the landing pane. Classify each lane per the manage-swarm rubric: active_working, blocked_declared (with hard external blocker), parked_handoff, parked_unassigned, dormant, shell, stuck-in-tui.
  IDLE for this loop = anything other than active_working OR a real blocked_declared with a hard external blocker.
  Tmux pane content is the authoritative source. Scrollback alone is not proof of motion (see swarm principle 5.1).

STEP 2 — Full root cause analysis on EVERY idle worker.
  For each idle lane, do not stop at "xsm broken". Do all of:
    1. Capture the pane (last 60 lines).
    2. Tail the latest xsm wrangle-run events.jsonl
       (latest=$(ls -t /Users/jv/projects/xenota/.xsm-local/log/swarm-backlog/wrangle-runs/ | head -1)
        and read $latest/events.jsonl) — find the exact classification + dispatch decision xsm made for this lane in the last 3 passes.
    3. Tail the supervisor patrol output (events with "agent": "main") — confirm the supervisor saw this lane and what action it took or skipped.
    4. Identify which tier failed and why:
       - xsm classified the pane wrong (e.g. parked_unassigned read as active_working)?
       - xsm classified correctly but dispatcher rejected the candidate bead (filter mismatch, lease conflict, fencing epoch)?
       - Supervisor patrol fired but did not walk parked_unassigned lanes?
       - Supervisor patrol did not fire at all (interval drift, missing @xsm_role tag on pane, daemon hung)?
    5. Write a one-paragraph RCA that names the function, the events.jsonl signature, and the smallest reproducible scenario. Save it as evidence for STEP 3.

STEP 3 — File OR confirm a P0 bead for the systemic gap.
  Search bd for an existing matching bead first — phrase the symptom, not the fix:
    bd list --status open --json | jq '.[] | select(.title|test("<keyword from RCA>";"i")) | {id,title,priority,labels}'
  Three outcomes:
    (a) Existing P0 bead with matching signature → bd comment <id> with fresh evidence (events.jsonl excerpt path + line range, pane snippet, tick ISO timestamp).
    (b) Existing bead at lower priority → bd update <id> --priority 0 then bd comment with new evidence.
    (c) No matching bead → file a new P0:
        bd create --type bug --priority 0 --labels swarm,fast-track --title "<one-line failure mode>" --stdin <<'BODY'
        ## RCA
        <paragraph from STEP 2>
        ## Evidence
        - events.jsonl: <path + line range>
        - pane: <snippet>
        - tick: <ISO timestamp>
        ## Repro
        <smallest reproducer>
        ## Fix surface
        <which file in xenon/packages/xsm/src/xsm/ owns this>
        BODY
  After the write, run bd dolt push and verify it reports a successful push. (bd has no `sync` subcommand.)
  Filing the bead is MANDATORY even when STEP 4 unblocks the swarm tactically — the bead is the durable record of the systemic gap.

STEP 4 — Manually unstick the lane so the swarm keeps moving.
  Even with the systemic fix tracked, do not leave the worker parked. For each idle lane:
    - parked_unassigned / dormant: walk Work Priority Order (fast-track → P0 → assigned-epic children → standalone P1 → other P1) and dispatch via /Users/jv/projects/xenota/.claude/skills/manage-swarm/scripts/clear_and_assign.sh <worker> '<assignment>'. Use the standing-order template from manage-swarm (start-feature-first, no plan-approval pause, prepare-review on completion).
    - stuck-in-tui operator gates (claude permission dialog, codex options menu, gemini rewind modal): RESOLVE IN-BAND per the prime directive. The wrangler IS the operator. Never escalate "to a human". See manage-swarm "Operator gate resolution policy".
    - shell (CLI dead): relaunch the CLI in the worker's worktree, verify pane_current_command flips to claude/node/gemini, then dispatch.
    - blocked_declared with a hard external blocker: route the dependency, file/comment the blocker bead, do not nudge the blocked worker.
  After every intervention, re-capture the pane within 60s and confirm visible motion (Working / Thinking / live tool output / Grooving / Deliberating). Helper success status is necessary but not sufficient — pane motion is the proof.
  ONE intervention per lane per tick. If a single clear_and_assign does not produce motion, classify as failed_reset and reroute or escalate; do NOT stack messages.

STEP 5 — Landing queue check.
  List CLEAN + APPROVED xenon PRs unmerged:
    cd /Users/jv/projects/xenota/xenon && gh pr list --state open --json number,title,mergeStateStatus,reviewDecision,headRefName | jq '[.[] | select(.mergeStateStatus=="CLEAN" and .reviewDecision=="APPROVED")]'
  Capture the landing pane (the dedicated landing worker, e.g. `last`).
  - If 3+ CLEAN+APPROVED xenon PRs are unmerged AND the landing lane is idle/parked: dispatch the landing worker onto the next landing slice via clear_and_assign.sh using the canonical landing handoff message (see manage-swarm "Landing-worker handoff pattern" — read-landing-skill-first, in-band merge authority, no human-approval stop).
  - If the landing lane is mid-flight: leave it. Re-check next tick.
  - If a CLEAN PR has been sitting >30 min with the landing lane stuck: file/extend a landing-blocker bead via /Users/jv/projects/xenota/.claude/skills/manage-swarm/scripts/landing_blocker.sh.
  Do NOT merge xenon PRs from this loop. Merge authority is the landing role's. Only break this in an explicit operator-authorized emergency.

STEP 6 — Pointer bump + xsm restart trigger.
  After 3-5 xenon PRs have merged into xenon/main since the last xenota top-level pointer commit, the swarm benefits from a bundled pointer bump (see manage-swarm "Bundled batch landing"):
    - Diff: list xenon SHAs merged since the current submodule pointer:
        cd /Users/jv/projects/xenota && PTR=$(git ls-tree HEAD xenon | awk '{print $3}')
        cd xenon && git log --oneline ${PTR}..origin/main
    - This is normally the landing lane's job. From the wrangle loop, ONLY act if the landing lane has not bumped within 30 min of the last xenon merge AND the operator has not vetoed in-chat. Otherwise leave it for the landing lane and re-check next tick.
    - When acting: invoke the land-submodule-stack skill / formula. Do not improvise the bash. The formula handles the bundled pointer commit message ("bump xenon: xc-ab12, xc-cd34, ...") and the workspace cleanup.
    - After the pointer commit lands on xenota/main, restart xsm so the daemon picks up the new code:
        /Users/jv/projects/xenota/.claude/skills/manage-swarm/scripts/restart_xsm.sh --reason post-merge-xsm-change --sha <xenon-sha>
      This is a signal-only restart (SIGTERM to the wrangle child); xsm_relaunch_loop.sh respawns from the new code. Verify by watching events.jsonl grow + pane emitting `wrangle run … pass N` for at least one full pass.
    - NEVER restart xsm with a known traceback unfixed. Capture the traceback, fix the code (Step 0 / file P0 bead), then restart.

STEP 7 — Emit a tight changelog.
  One tick = one short report. Keep it under ~12 lines:
    tick <ISO>: <N> idle workers, <N> P0 beads filed/updated, <N> lanes dispatched, <N> PRs landed, xsm <restarted|stable>
    - <worker>: <RCA one-liner> → bead <id>; dispatched to <bead-id>
    - landing: <state> (<N> CLEAN+APPROVED xenon PRs queued)
    - pointer: <bumped to <sha>|skipped because <reason>>
  If everything is quiet: "all lanes active, landing queue at <N>, no pointer bump" — and stop.

HARD RULES (apply on every tick, do not soften):
  - NEVER classify a non-active_working lane as fine because "the operator might be steering it" unless fresh user input is visible in pane scrollback within the last 5 minutes.
  - NEVER nudge a worker more than once per tick. One intervention, one re-capture, then classify and reroute or escalate.
  - NEVER skip the P0 bead in STEP 3 — even when STEP 4 immediately unblocks the lane. The bead is the durable record of the systemic gap; without it, the failure recurs.
  - NEVER bump the xenota pointer for a single PR outside an explicit emergency hotfix.
  - NEVER restart xsm while a traceback is unfixed.
  - NEVER touch landing-lane branch surgery or merge a PR whose author flavor matches your driver.
  - Two consecutive ticks with the same idle pattern + no progress on the systemic fix = STOP THIS LOOP and switch to unblock-swarm for a deeper diagnosis pass. Tell the operator explicitly.

Read manage-swarm and unblock-swarm skills if you need a refresher on helper script paths or the operator-gate resolution policy.
```

## Stopping the loop

The operator stops it via `/loop stop` (or by killing the scheduled wakeup). The loop runs until explicitly stopped — it does not self-terminate even when the swarm is quiet, because quiet ≠ healthy in a swarm. A continuous wrangler is the safety net.

Exception: the prompt's last hard rule tells the loop itself to stop and escalate to `unblock-swarm` after **two consecutive ticks** with the same unresolved idle pattern. That is the loop self-detecting that nudging is not the fix.

## What this skill does NOT do

- It does not run the wrangle pass directly — it only installs the loop. The first tick fires after 5 minutes; if the operator wants an immediate pass, run the prompt body once before installing the loop.
- It does not start xsm or open worker windows. Bootstrap belongs to `manage-swarm` (see "Bootstrap completion gate").
- It does not replace `unblock-swarm` for genuinely stuck states. The loop hands off to `unblock-swarm` when nudging fails twice in a row.
