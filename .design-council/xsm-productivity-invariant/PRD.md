# PRD: XSM autonomy — from productivity invariant to self-driving swarm

Status: draft v1
Date: 2026-04-20
Author: jv (with claude)
Supersedes / extends: `proposal.md` (xc-iicr, now closed)

## 1. Context

`xc-iicr` established the worker-productivity invariant: a non-landing worker lane must be producing evidence of progress or be in a narrowly authorized waiting state. That work closed the mechanism-level bug where lanes sat stranded.

This PRD is the next layer: what roles, loops, and feedback must exist around XSM so the swarm runs itself with minimal operator intervention, and so XSM actively escalates when it cannot.

Symptoms that motivate this PRD (observed 2026-04-19 to 2026-04-20):
- Supervisor went dormant for ~10 minutes while `xsm wrangle` was alive; patrol messages were sent but supervisor skipped every time (`should_intervene=true`, `action=skip`, `ladder_position=0`).
- Supervisor parked at a codex approval dialog that only a human could see; xsm had no mechanism to surface that.
- Landing, merging, dispatch, and xsm-daemon restarts were all piling on the supervisor role; no loop owned them distinctly.
- Beads were filed reactively by the operator; no role was curating the backlog into strategy → tactics.
- No role was watching XSM itself — when xsm crashed (the `release_lease` iteration bug), only the human noticed.

## 2. Desired end state

A swarm where, given a non-empty backlog and a live operator check-in once every few hours:

- Workers make measurable progress on beads.
- PRs get reviewed, landed, and bead-closed without operator involvement for routine changes.
- When the swarm stalls, XSM itself raises a visible, loud signal — not a silent `skip` in a jsonl file.
- The backlog is continuously groomed: acceptance criteria present, priorities current, epics broken into tactical beads.
- When XSM, strategies, repertoires, roles, or skills themselves need work, a Monitor role sees the gap and files the bead.

Non-goals for v1:
- Fully-autonomous operation across multi-day horizons without any operator review.
- Self-modifying xsm code without human approval.
- Multi-repo landing (v1 watches one repo).

## 3. Role model

Six roles. Each owns exactly one thing.

| Role | Owns | Pane / loop trigger |
| --- | --- | --- |
| **Worker** | Implementing an assigned bead | Per-lane, dispatched by xsm |
| **Wrangler** | Keeping lanes moving (nudge, reset, reassign); resolving simple blockers | xsm patrol, interval-driven |
| **Supervisor** | Resolving worker blockers that wrangler escalates; authority decisions | xsm patrol, interval-driven |
| **Landing** | Reviewing and landing mergeable PRs from a watched GitHub repo | Polls/webhooks PR list |
| **Product Owner** | Backlog grooming: strategy → epics → tactical beads with acceptance criteria | Interval patrol + event trigger on PR merge |
| **XSM Monitor** | Watching XSM itself (daemon, roles, repertoire, skills, strategies) and filing beads against gaps | Interval patrol |

Roles 1–3 exist today. Roles 4–6 are new.

### 3.1 Supervisor (narrowed)

Current supervisor prompt conflates landing, dispatch, xsm-rebuild, and blocker-resolution. After this PRD:

- Supervisor only handles blockers that wrangler escalates to it.
- No more landing / merging.
- No more xsm restart responsibility.
- No more "keep everyone moving always" (that's wrangler's job).
- Standing orders collapse to: read leader-backlog, act on blocker entries, ack.

### 3.2 Landing (new)

Trigger: polls (or webhook-subscribes to) a configured GitHub repo for PRs in a watched state (`open + not-draft + mergeable`).

Per-PR processing loop:

1. **Resolve bead** from PR title prefix (`xc-XXXX: …`), branch name (`xc-XXXX-*`), or body `Bead:` trailer.
   - No bead → comment "missing bead link", label `landing/no-bead`, skip.
   - Bead ID doesn't resolve via `bd show` → label `landing/stale-bead`, skip.
2. **Review** the diff against the bead's acceptance criteria and CI status.
3. **Verdict**:
   - `APPROVE` → land via the appropriate formula; `bd close` the bead.
   - `FIX_INLINE` → ≤10-line mechanical fix (typo, lint, missing changelog line); commit with `[landing-fix]` prefix, re-run CI, land. Post a bead comment: `landing: inline fix applied — <summary> (<PR link>, <commit sha>)`.
   - `REWORK` → throw back with structured notes (see §3.2.1).
   - `ESCALATE` → push to leader-backlog (self-merge rail, policy conflict, out-of-scope).
4. **Auto-restart hook** (after successful land): inspect merged diff paths. If any touch `xenon/packages/xsm/**`, `.xsm-local/strategies/**`, `.xsm-local/repertoire/**`, `.claude/skills/**`, or role configs, trigger xsm daemon restart or role-pane `/clear` as appropriate.

**Rework ceiling**: after 3 REWORK cycles on the same bead, landing auto-escalates to leader-backlog. Configurable via `landing.rework_ceiling: 3` in strategy yaml.

**Self-merge rail**: landing's driver flavor must differ from PR author flavor. A codex-driven landing ESCALATEs codex-authored PRs.

**Repo scope (v1)**: one landing loop per watched repo. Revisit if operationally painful.

#### 3.2.1 Bead+branch completeness invariant

When landing issues `REWORK`, the bead becomes the sole source of truth for fix context. Landing must write onto the bead:

1. Verdict line: `landing: REWORK — <one-line reason>`
2. PR pointer: URL, head SHA, branch name
3. Concrete change list: numbered, each citing file path/line or a reproducible test name
4. What NOT to change: scope boundaries
5. Acceptance checklist landing will re-verify on resubmit

Landing also pushes a marker commit (`landing: rework requested — see bead xc-XXXX`) to the PR branch and posts a linking review comment. The bead transitions `in_review → rework`.

**Worker-pickup invariant**: a worker reassigned a reworked bead must be able to `bd show <bead>` + `git checkout <branch>` and know what to do — no back-channel, no "ask the supervisor what landing meant". If landing can't express the fix plainly in the bead, it's an ESCALATE.

### 3.3 Product Owner (new)

Trigger: interval patrol + event trigger on PR merge.

Responsibilities:
- Read recent merges and closed beads; identify follow-up work.
- Decompose epics into tactical beads sized for a single worker session.
- Ensure every dispatchable bead has acceptance criteria (hard gate for landing, see §6).
- Maintain priority order across the backlog so wrangler picks the right next work.
- File improvement beads for recurring friction seen in leader-backlog entries.

PO is not a coder. PO writes beads and nothing else. PO runs in its own pane.

### 3.4 XSM Monitor (new)

Trigger: interval patrol.

Responsibilities (diagnostic, filing beads — not fixing):
- Classify XSM failures into one of: `xsm-library`, `strategy`, `repertoire`, `role`, `skill`, `infrastructure`.
- Watch `events.jsonl` for pathological patterns: repeated `skip` with `should_intervene=true`, ladder_position stuck at 0, same reset_and_assign 3+ times.
- Watch daemon pane for tracebacks; if detected, file a `type=bug` bead with the traceback captured.
- Periodically sanity-check the strategy yaml, repertoire files, and skill index against referenced agents / roles.
- File beads with the appropriate classification and route them to the right epic.

Monitor is the feedback loop that makes the swarm self-improving.

## 4. The five loops

| Loop | Owner | Frequency | Produces |
| --- | --- | --- | --- |
| Product | Product Owner | ~1/hr + on merge | groomed backlog, epics, acceptance criteria |
| Execution | Worker + Wrangler | continuous (xsm patrol) | PRs |
| Landing | Landing role | ~1/min poll | merges, bead closes, rework throwbacks |
| Blocker | Supervisor | on leader-backlog entry | unblocked workers, authority decisions |
| Meta | XSM Monitor | ~1/10min | new beads against xsm/strategy/repertoire/roles/skills |

The five loops are deliberately decoupled. None blocks another; each writes to `bd` or `leader-backlog` as the shared substrate.

## 5. RED state — XSM must throw a fit when silent

Currently, XSM prints `wrangle run ... pass N: no actions` forever while workers are parked. That is the single most-violated invariant.

New invariant:
- If backlog has dispatchable beads AND worker capacity exists AND no dispatch/reset action has occurred in the last N passes (default 5), XSM enters RED.
- RED state: the daemon pane header flips to a loud banner (color, prefix), a `swarm.red` event is emitted, and leader-backlog gets a top-priority entry.
- Supervisor and XSM Monitor both see RED as a top-of-queue item on next patrol.
- RED clears only when a dispatch or reset action happens, or when operator acks.

Precondition fixes required to make RED meaningful:
1. **No-silent-skip**: preflight classifying `should_intervene=true` must not emit `action=skip`. Today's supervisor log shows 42 of these. Either intervene or emit a structured "cannot intervene because X" that counts against RED.
2. **Ladder position advancement**: supervisor's `ladder_position` is stuck at 0 across 62 decisions. The ladder must advance when `nudge` is emitted, else `reset_and_assign` never fires.

## 6. Architecture changes

### 6.1 Typed event stream

Today's `events.jsonl` is hand-rolled. Machine-readable for grep but not for consumers. Needed:
- Schema file (pydantic or jsonschema) for each event type.
- Stable event categories: `assignment.*`, `patrol.*`, `swarm.*`, `lease.*`.
- A Python client library so Monitor / Landing / PO can subscribe without parsing free-form JSON.

### 6.2 Human-readable wrangle output

`xc-y6xi2` already exists — wrangle pane must emit short human-readable lines alongside (or instead of) raw JSON. Precondition for dashboard (`xc-4acej`).

### 6.3 Acceptance-criteria gate

Every worker-dispatched bead must have non-empty acceptance criteria. Lint rule enforced at dispatch time; PO alerted when beads fail the gate.

### 6.4 Strategy-yaml role bindings

Add `landing`, `product_owner`, `xsm_monitor` role packages alongside `wrangler`, `supervisor`, `worker`. Each with distinct startup_prompt, standing_orders, patrol settings.

## 7. Milestones

- **M0 — foundation fixes** (unblocks everything else):
  - No-silent-skip fix in preflight.
  - Ladder position advancement fix.
  - Typed event stream (schema + library).
  - Human-readable wrangle output (xc-y6xi2).

- **M1 — Landing loop**:
  - Landing role package + startup prompt.
  - GitHub-repo watcher (poll first, webhook optional).
  - Bead resolver; review/verdict prompt; FIX_INLINE discipline.
  - Rework throwback template + bead completeness invariant.
  - Auto-restart hook for xsm-touching landings.
  - Rework ceiling enforcement (3 → ESCALATE).

- **M1.5 — Supervisor narrowing**:
  - Remove landing/merge/dispatch responsibilities from supervisor prompt.
  - Update standing_orders.
  - Update review-swarm / unblock-swarm skills to match.

- **M2 — XSM Monitor**:
  - Monitor role package.
  - Failure classification taxonomy.
  - Events.jsonl pattern detectors (skip-with-intervene, ladder-stuck, reset-loop).
  - Bead filing with correct epic routing.

- **M3 — RED state**:
  - Dispatch-starvation detector (build on xc-iicr work).
  - Pane banner + `swarm.red` event.
  - Leader-backlog top-priority escalation.
  - Operator ack path.

- **M4 — Product Owner**:
  - PO role package.
  - Acceptance-criteria lint at dispatch.
  - On-merge trigger (new event from Landing).
  - Dashboard integration (xc-4acej) shows backlog health.

## 8. Proposed beads

To be filed as part of this PRD:

Epics:
- **XSM autonomy** (parent epic for everything below)
- **Landing loop** (M1)
- **XSM Monitor role** (M2)
- **Product Owner role** (M4)
- **Supervisor narrowing** (M1.5)

Tactical beads (M0 foundation):
- No-silent-skip preflight fix
- Ladder position advancement fix
- Typed event stream API
- (xc-y6xi2 already exists for human-readable wrangle)
- (xc-4acej already exists for dashboard)

Tactical beads (M1 landing):
- GitHub PR watcher (bead resolver, verdict prompt)
- Auto-restart hook on xsm-touching landings
- Rework ceiling enforcement
- Bead+branch completeness invariant

Tactical beads (M3 RED):
- Dispatch-starvation RED state

## 9. Open questions

1. Landing driver flavor — if we want codex+claude landing loops for cross-check, we need per-flavor self-merge rails coded. v1 assume single-flavor landing.
2. PO's authority to close beads without PR — should PO be able to close a bead as obsolete, or only mark deprecated? Propose: PO can close with `reason=obsolete`, operator can reopen.
3. XSM Monitor creating beads about the Monitor itself — avoid loop via a dedupe window.
4. Webhook infrastructure — a local listener on the operator's machine is fragile. First version: polling at 60s interval.
5. Does RED state auto-resume wrangle after ack, or does it require a manual `xsm wrangle` restart? Default: auto-resume.

## 10. Non-goals / deferred

- Cross-repo landing (one repo for v1).
- Automatic rollback of landed changes that break main (rely on CI gates).
- PO using LLM to synthesize strategy from nothing — PO only decomposes epics the operator or Monitor filed.
- Self-modifying xsm code without PR review.
