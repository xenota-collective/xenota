# XSM Clean-Run Handoff

Date: 2026-04-13
Repo: `/Users/jv/projects/xenota`
Scope: get XSM back to a state where it can run continuously in `xc:0.2`, on the default tmux server only, without interrupting active workers, without misrouting wrangler work, and without leaving workers idle when they should be progressing.

## Operating Constraints

- Run XSM only in the visible tmux pane the operator designates. Do not launch it as a background shell job.
- Do not use the GT tmux socket. XSM and helper scripts must operate on the default tmux server only.
- If a live run shows bad behavior, kill XSM immediately, fix the code, then restart.
- Never interrupt an actively working lane.
- Wrangler must only receive wrangling work: blocks, patrol supervision, and explicit wrangler directives.
- Worker lanes and patrol lanes are intentionally different and must not share the same dispatch assumptions.
- Assigned worker beads are pinned by default. Continuity is preferred when prior work exists, but idle workers can be moved on.
- If there is no work to dispatch, idle is acceptable. XSM should continue checking for new work without emitting incidents.

## Definition Of “Running Cleanly”

XSM is only considered healthy when all of the following are true:

1. It runs inside the intended tmux pane, not as an off-pane background process.
2. It never touches GT tmux.
3. It does not send `/clear`, reset, or any other interrupting action to a lane that is actively working.
4. It does not send generic worker prompts to wrangler.
5. When a worker declares a real block and wrangler is free, wrangler is engaged immediately with block context.
6. If wrangler is busy, the block is retained deterministically and not lost.
7. Worker assignment state matches live branch/worktree reality.
8. Handoff-ready lanes are protected by a strong QA gate and are not recycled back into generic execution.
9. Idle workers without demand can sit idle quietly, while XSM keeps polling for new work.
10. Restart clears disabled-lane state by default.

## Known Failure Modes

These are the concrete classes of failure observed during live runs.

### 1. XSM Was Run Outside The Intended Pane

- Bounded `xsm wrangle --iterations ...` runs were launched as background shell jobs rather than inside the operator-visible tmux pane.
- This made process ownership unclear and violated the requirement that XSM only run in the current pane.
- A stray run was later confirmed by `ps` and killed.

Impact:

- The operator could not trust where XSM was running.
- Manual intervention and automated actions were harder to separate.

Required fix:

- Do not run validation loops as background jobs.
- Only launch XSM directly in the current pane.
- If ad hoc diagnostics are needed, use non-daemon commands that fully complete in the same pane or inspect logs/state without launching background runners.

### 2. GT Tmux Contamination

- Some manage-swarm helper scripts were still invoking `tmux -L gt`.
- This created or manipulated worker sessions on the GT socket instead of the default server.
- A `worker-claude-2` session appeared on the wrong server during live testing.

Impact:

- Workers appeared in the wrong tmux universe.
- The visible `xc` session no longer reflected actual control state.

Fix status:

- Patched local helper scripts to use the default tmux binary without `-L gt`.

Files already changed:

- `.claude/skills/manage-swarm/scripts/tmux_target.sh`
- `.claude/skills/manage-swarm/scripts/capture_pane.sh`
- `.claude/skills/manage-swarm/scripts/capture_polecat.sh`

Remaining validation:

- Re-run the full flow and confirm no GT session or GT window is created anywhere.
- Confirm workmux-driven provisioning still behaves correctly when XSM starts workers.

### 3. Wrangler Received Generic Worker Work

- Wrangler was sent a generic execution-style prompt instead of a wrangling directive.
- This is a hard contract violation.

Impact:

- Wrangler can start doing normal feature work instead of orchestration.
- Real blocks and patrol work can be delayed or ignored.

Fix status:

- Execution boundary now blocks generic worker prompts from being sent to wrangler.
- Explicit wrangler directives are allowed only via dedicated metadata.
- Added blocked-lane routing support and wrangler-specific routine selection.

Files already changed:

- `xenon/packages/xsm/src/xsm/executor.py`
- `xenon/packages/xsm/repertoire/routines/handle_blocked_lane/config.yaml`
- `xenon/packages/xsm/repertoire/routines/handle_blocked_lane/prompt.md`
- `xenon/packages/xsm/repertoire/selector/config.yaml`
- `xenon/packages/xsm/repertoire/selector/prompt.md`
- `xenon/packages/xsm/prompts/wrangler.md`
- `xenon/packages/xsm/roles/wrangler.yaml`
- `xenon/packages/xsm/src/xsm/strict.yaml`

Remaining validation:

- Confirm every wrangler action during a live run is either patrol supervision or block handling.
- Confirm wrangler never receives a worker execution prompt even under stale monitor state, patrol escalation, or retry paths.

### 4. Wrangler Was Triggered Correctly But Then Did Nothing Useful

- A later run improved the wrangler prompt, but wrangler still failed to actually unblock or triage effectively.
- The user explicitly wants “unblock this worker” to exist as a real strategy/RPT path, not just an ad hoc live escalation.

Impact:

- Correct routing is not enough if wrangler behavior after routing is weak.
- Workers can stay blocked while XSM claims they were escalated properly.

Required fix:

- Strengthen the wrangler strategy so a declared worker block becomes a deterministic unblock workflow.
- Encode the unblock flow as a repertoire/strategy path that can be evaluated.
- Add eval coverage for blocked worker intervention quality, not just routing correctness.

Open implementation work:

- Review current wrangler prompts, strategy selection, and expected block payloads.
- Ensure wrangler receives enough context to take action:
  - worker name
  - bead id/title
  - branch/worktree
  - block declaration
  - last relevant pane evidence
  - next required decision
- Add tests/evals proving wrangler takes unblock action instead of stalling.

### 5. Active Workers Were Interrupted By Stale Plans

- XSM sent reset or clear actions after a prior classification even though the worker was already moving again by execution time.
- This happened most visibly around `/clear` and reset behavior.
- The user requirement is stronger than “prefer not to”: every interrupt should be guarded, and XSM should refuse to interrupt if the lane is actually working.

Impact:

- A worker can be kicked out of valid progress.
- Manual trust in XSM collapses immediately when this happens.

Fix status:

- Execution preflight blocks reset/restart actions on active lanes.
- Added tracker rewind when execution-time interrupt guard blocks a stale planned action, so stale plans do not keep climbing the escalation ladder.

Files already changed:

- `xenon/packages/xsm/src/xsm/main.py`

Remaining validation:

- Live test a case where a worker goes from idle-looking to active before execution and confirm:
  - no interrupt is delivered
  - escalation ladder does not advance
  - later passes observe the lane as healthy

### 6. Parked / Handoff Lanes Were Being Redispatched As If Idle

- A worker with handoff-shaped state was classified as `parked_off_mission`, causing XSM to plan `reset_and_assign`.
- Executor correctly refused once it saw the live lane was not safely interruptible, but the planner should not have emitted the action in the first place for handoff-like states.

Impact:

- Handoff-ready work risks being blown away or re-opened incorrectly.
- The system wastes cycles planning invalid recovery actions.

Fix status:

- `ParkedOffMissionHandler` now skips intervention when the lane is actually handoff/approval-shaped.

Files already changed:

- `xenon/packages/xsm/src/xsm/wrangle.py`

Remaining validation:

- Confirm strong QA/handoff states are reliably recognized from realistic pane text.
- Confirm handoff-ready workers stay protected across restart, monitor drift, and multi-pass wrangle runs.

### 7. Live Worker Assignment Drifted From Monitor State

- `worker-claude-2` was working on `xc-asiu`, but monitor still thought it was assigned to a different bead from stale backlog metadata.
- `worker-claude-1` also showed branch/assignment drift in later snapshots.

Impact:

- XSM can make the right decision on the wrong bead.
- Workers can be redispatched or escalated based on stale metadata instead of live branch reality.

Fix status:

- Monitor now reconciles worker assignment from the live worktree branch.
- If the branch bead is not present in static backlog YAML, monitor falls back to the live bead backend.

Files already changed:

- `xenon/packages/xsm/src/xsm/monitor.py`

Remaining validation:

- Confirm worker branch, bead id, and assignment title stay aligned through:
  - fresh dispatch
  - worker-created branch changes
  - reassignment
  - restart
  - handoff-ready state

### 8. Wrangler Reclassified Itself From Its Own Intervention Text

- Wrangler’s own block-handling messages were parsed back as if wrangler itself had become blocked.

Impact:

- Self-referential state pollution.
- Bad follow-up decisions and possible repeated wrangler nonsense.

Fix status:

- Added ignore patterns for wrangler blocked-lane directive/result text in tmux classification.

Files already changed:

- `xenon/packages/xsm/src/xsm/tmux.py`

Remaining validation:

- Confirm wrangler output can include intervention summaries without changing wrangler’s own state classification.

### 9. Injected Follow-Up Actions Did Not Always Execute

- Some injected actions only executed on specific result paths rather than after any relevant result.

Impact:

- Planned recovery chains could silently stop midway.

Fix status:

- Injected actions now execute after any result, not just patrol-originated results.

Files already changed:

- `xenon/packages/xsm/src/xsm/main.py`

Remaining validation:

- Run scenarios where worker results inject follow-up actions and confirm they execute deterministically.

### 10. Idle Prompt Verification Was Brittle

- `worker-claude-1` hit `failure_kind: idle_prompt_missing` during a `reset_and_assign` even though the lane was effectively at a prompt state.
- The second pass then saw live output and correctly blocked interruption, but the first-pass failure indicates prompt detection / reset verification is still brittle.

Impact:

- False negatives on safe reset windows.
- Spurious retries and confusing state transitions.

Required fix:

- Inspect the idle prompt detector around `/clear` verification.
- Make prompt verification robust to prompt redraw timing and lane-specific shell behavior.
- Distinguish “did not detect prompt yet” from “unsafe to reset”.

Open implementation work:

- Capture exact pane text for the `worker-claude-1` failure shape.
- Add a regression test for prompt redraw after `/clear`.
- Consider a short bounded poll before declaring `idle_prompt_missing`.

### 11. Restart Must Clear Disabled Lanes By Default

- The user explicitly required restart to guarantee disabled lanes are cleared.

Impact:

- A restart cannot be trusted as a clean recovery if disabled state persists unexpectedly.

Required fix:

- Audit restart path and confirm disabled-lane state is cleared deterministically.
- Add tests that exercise restart from a dirty lane-disable state.

Open implementation work:

- Verify whether the current restart path already does this everywhere or only in some flows.
- If partial, centralize disabled-lane reset in restart bootstrap.

### 12. Patrol Lanes And Worker Bead Lanes Need Distinct Handling

- The user explicitly stated patrol lanes should be treated completely differently from worker bead lanes outside bead validation.

Impact:

- Shared assumptions can cause wrong prompts, wrong idle handling, and wrong escalation.

Required fix:

- Audit planning and execution code for worker-lane defaults leaking into patrol-lane handling.
- Separate lane-class-specific logic where needed.

Open implementation work:

- Review lane role modeling in monitor, planner, strict strategy, and executor.
- Add tests proving patrol lanes do not inherit worker redispatch behavior.

### 13. Block Detection Should Be Lightweight And Then Hand Off To Wrangler

- The user wants blocks primarily declared by the worker.
- XSM may ask if a worker is blocked when there is lots of work and no visible progress.
- Deep diagnosis should go to wrangler, not live in the bead itself.

Impact:

- Over-eager automated blockage logic can thrash workers.
- Under-eager logic leaves workers stalled.

Required fix:

- Keep detector narrow:
  - tmux activity
  - self-reported status
- Route identified blocks to wrangler immediately when available.
- Preserve context in strategy / feature bead, not on the worker bead itself.

Open implementation work:

- Audit block classifier inputs.
- Confirm there are no hidden heuristics using unrelated signals.
- Add eval coverage around “slow but working” versus “stalled and blocked”.

## Tests Already Added Or Updated

These areas already have direct regression coverage added during the current fix cycle:

- wrangler blocked-lane parsing and self-ignore behavior
- blocked-lane routing
- injected follow-up actions
- stale live-branch assignment reconciliation
- parked handoff lane protection
- escalation ladder rewind after interrupt-guard rejection

Primary touched tests:

- `xenon/packages/xsm/tests/test_tmux.py`
- `xenon/packages/xsm/tests/test_main.py`
- `xenon/packages/xsm/tests/test_monitor.py`
- `xenon/packages/xsm/tests/test_wrangle.py`

Additional touched tests pending broader review:

- `xenon/packages/xsm/tests/test_repertoire_bridge.py`
- `xenon/packages/xsm/tests/test_strategy.py`
- `xenon/packages/xsm/tests/test_workmux.py`

## Remaining Work To Finish Before Another “Clean” Claim

This is the shortest honest list of what still needs to be done.

1. Fix idle prompt verification around `/clear` and `reset_and_assign`, especially the `idle_prompt_missing` failure shape.
2. Audit and guarantee restart clears disabled lanes by default.
3. Turn wrangler unblock behavior into a deterministic strategy/RPT path with eval coverage, not just routing.
4. Audit patrol-lane versus worker-lane handling and separate any remaining shared assumptions.
5. Run a full live test in `xc:0.2` only, with no off-pane runners, and verify:
   - no GT activity
   - wrangler gets only wrangling work
   - blocked workers are escalated immediately when wrangler is free
   - active workers are never interrupted
   - handoff-ready lanes are never recycled
   - idle-no-demand lanes remain quiet
6. If any one of those fails during the run, kill XSM immediately and return to code fixes before restarting.

## Suggested Live Validation Sequence

Use this order so failures are attributable.

1. Verify no `xsm` process is running anywhere.
2. Verify no GT tmux sessions/windows were created by recent tooling.
3. Start XSM only in the intended `xc:0.2` pane.
4. Observe first dispatch:
   - worker-claude-1 gets worker work
   - worker-claude-2 gets worker work
   - wrangler gets patrol/wrangling context only
5. Observe one worker in active motion and confirm XSM does not `/clear` or reset it.
6. Force or wait for one authentic block declaration and confirm wrangler is engaged immediately.
7. Confirm restart clears disabled-lane state.
8. Confirm no hidden side effects appear on another tmux server or off-pane shell.

## Current Local Change Areas

As of this handoff, local XSM-related changes exist under:

- `xenon/packages/xsm/prompts/wrangler.md`
- `xenon/packages/xsm/repertoire/selector/config.yaml`
- `xenon/packages/xsm/repertoire/selector/prompt.md`
- `xenon/packages/xsm/repertoire/routines/handle_blocked_lane/`
- `xenon/packages/xsm/roles/wrangler.yaml`
- `xenon/packages/xsm/src/xsm/executor.py`
- `xenon/packages/xsm/src/xsm/main.py`
- `xenon/packages/xsm/src/xsm/monitor.py`
- `xenon/packages/xsm/src/xsm/strict.yaml`
- `xenon/packages/xsm/src/xsm/tmux.py`
- `xenon/packages/xsm/src/xsm/workmux.py`
- `xenon/packages/xsm/src/xsm/wrangle.py`
- `xenon/packages/xsm/tests/test_main.py`
- `xenon/packages/xsm/tests/test_monitor.py`
- `xenon/packages/xsm/tests/test_repertoire_bridge.py`
- `xenon/packages/xsm/tests/test_strategy.py`
- `xenon/packages/xsm/tests/test_tmux.py`
- `xenon/packages/xsm/tests/test_workmux.py`
- `xenon/packages/xsm/tests/test_wrangle.py`
- `.claude/skills/manage-swarm/scripts/tmux_target.sh`
- `.claude/skills/manage-swarm/scripts/capture_pane.sh`
- `.claude/skills/manage-swarm/scripts/capture_polecat.sh`

## Bottom Line

XSM is not yet in a state where it should be described as fully clean or fully trustworthy in live continuous operation.

The major routing and protection fixes are partly in place:

- wrangler generic-prompt protection
- blocked-lane routing
- live branch reconciliation
- handoff-lane protection
- interrupt-ladder rewind
- GT helper script cleanup

The remaining gap is not theoretical. It is the difference between “substantially less broken” and “safe to run continuously”:

- robust reset verification
- disabled-lane reset guarantee
- real wrangler unblock behavior
- strict lane-type separation
- one successful live run in the correct pane with no contract violations
