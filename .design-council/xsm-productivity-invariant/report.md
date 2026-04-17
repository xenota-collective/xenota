Verdict: Conditional Go

Consensus
- The bead is aimed at the right layer. This is a control-plane / mechanism defect, not a narrow stale-assignment cleanup bug.
- The strongest part of the plan is the shift to a hard worker-productivity invariant with explicit authorized exceptions instead of incident-specific handling.
- The current plan is directionally correct but underspecified. The highest-risk gap is not defining exactly what counts as productivity evidence, what counts as dispatchable backlog, and which state source wins when `bd`, persisted XSM state, leases, worker self-report, worktree state, and tmux observations disagree.
- `parked_handoff` is overloaded and must be split. True landing handoff must become a role-scoped state distinct from generic worker no-work / redispatchable states.
- Recovery paths need stronger structure. Not every stranded lane should go straight to redispatch; the system needs at least `redispatch`, `phase_advance`, and `quarantine` as distinct recovery outcomes.
- Authorized non-productive states need a schema, not just names. At minimum they need reason, owner, expiry or max passes, recheck policy, and next action. Without that, XSM will recreate limbo under new labels.
- The plan needs anti-thrash controls: explicit pass/time thresholds, recovery rate limits, repeated-failure quarantine, and starvation-incident deduplication.
- Patrol / supervisor / wrangler lanes need an explicit contract outside normal worker bead validation. The council agrees the current category error is real, though there was disagreement on whether to model this as a full separate lifecycle or a reserved synthetic ID path.
- A replay / reconciliation harness should exist before broad refactors. All three seats converged on the need for a fixed corpus of stale-state and restart scenarios to prevent oscillation and duplicate-dispatch regressions.

Disagreements
- Patrol modeling:
  The Systems Critic and Safety Auditor pushed for an explicit non-bead patrol contract with lifecycle semantics.
  The Execution Pragmatist argued for a simpler reserved `sys-*` bead bypass to avoid building a second state machine.
  Recommendation: adopt the explicit patrol contract in the spec, but implement the first cut with a narrow reserved-ID bypass only if it preserves the same contract boundaries.
- Rollout order:
  The Systems Critic wanted the authority model and lane-state table specified before automation broadens.
  The Safety Auditor and Execution Pragmatist both wanted automatic reclaim gated or observe-only first to gather false-positive data.
  Recommendation: do both in sequence. Specify the authority order and lane state table first, then ship starvation detection plus reclaim in observe-only mode before enabling destructive recovery.

Adopt Now
- Add a normative lane-state table to the bead / design spec.
  Required minimum states: `active`, `authorized_wait`, `redispatchable`, `landing_handoff`, `quarantined`, `retired`.
  For each state define: entry conditions, required metadata, max duration or pass budget, allowed roles, and next automatic action.
- Define productivity evidence explicitly.
  The spec should say what counts as fresh evidence by role/phase and what does not. Terminal output alone is insufficient. Candidate evidence types: assignment change, commit creation, test state change, QA/PR phase transition, acknowledged intervention outcome.
- Define dispatchable backlog explicitly.
  Backlog is dispatchable only if it passes role matching, dependency checks, package policy, gate ownership, and human-gate constraints.
- Define canonical authority order for reconciliation.
  Recommendation: bead validity first, then lease authority, then role/package constraints, then persisted XSM state, then worker self-report, then tmux heuristics. The exact order can differ, but the spec must make it explicit and deterministic.
- Split recovery outcomes into distinct classes.
  Do not let invalid context default directly to redispatch. Add explicit outcome categories: `redispatch`, `phase_advance`, `quarantine`.
- Add an authorized-wait schema.
  Minimum fields: `reason`, `owner`, `expires_at` or `max_passes`, `recheck_policy`, `next_action`.
  If any required field is missing, the lane is not authorized to wait and must be recovered.
- Add `operator_hold` as a first-class authorized state.
  This gives operators a bounded override that the productivity evaluator must respect.
- Add fencing / idempotency around assignment clearing.
  Before clearing assignment authority, XSM must verify the lane has not produced fresh progress evidence since the stale evaluation and must emit a structured audit event for the recovery action.
- Define concrete defaults for “bounded passes.”
  The spec currently says “bounded” but not how bounded. Make the thresholds package-configurable with required defaults for startup grace, starvation detection, and repeated-recovery quarantine.
- Add incident contract and deduplication.
  A dispatch-starvation incident should carry observed demand, role match result, available capacity, last recovery attempt, next action, and whether XSM remains safe to continue autonomous dispatch. Re-emission needs cooldown / dedup semantics.
- Build the lane-reconciliation harness before broad behavior changes.
  Use persisted stale assignment states and restart traces, including the 2026-04-12 failure, as fixed replay fixtures.

Backlog
- Decide whether patrol lanes should eventually have a dedicated lifecycle type rather than a reserved-ID carveout.
- Decide whether productivity evidence should be fully role-specific or partially shared across roles with per-role extensions.
- Decide whether dispatch starvation should become a swarm-level circuit-breaker after repeated incidents rather than just a lane-level incident.
- Decide whether automatic reclaim should remain package-configurable by role, since some roles may safely tolerate longer non-productive windows than generic workers.

No missing seat data. All three seats returned.
