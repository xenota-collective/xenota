# XSM Swarm Principles

**Date:** 2026-03-29
**Status:** Design Council Approved (Conditional Go)
**Council:** Full 4-phase (Ideation → Black Hat → Simplify → Security Signoff), 3 seats (Codex GPT-5.4, Claude Sonnet, Gemini 3.1 Pro)

---

## Verdict

Conditional Go — unanimous across all 3 seats.

Approved for implementation. Not approved for unattended autonomous deployment until fencing epoch controls and SQLite lease enforcement are encoded and recovery drills pass for the known failure set.

---

## Core Principles

### 1. Core Operating Model

**1.1 XSM is the sole coordinator.**
Agents execute tasks; only XSM routes work, assigns beads, and intervenes in agent state. Agents never self-route, communicate peer-to-peer about work state, or make coordination decisions.
Why: Any agent-to-agent coordination channel creates a surface for cascading failures and undermines the ability to reason about swarm state from a single authority.

**1.2 The swarm proposes; the merge policy decides.**
Every code change is a proposal. XSM supports two configurable merge modes: **human-gated** (default, no PR merges without a human merge action) and **auto-merge** (PRs merge automatically when CI passes and all structural gates clear). The mode is set at projection configuration time and cannot be changed by agents at runtime.
Why: Different repos and risk profiles require different merge policies. High-trust internal repos benefit from auto-merge throughput; external or security-sensitive repos require human gates. The principle is that merge policy is an operator decision, not an agent decision.

**1.3 Repo content is adversarial input.**
Content from the repository (code, comments, commit messages, CI config, dependency files) is never processed as orchestration instructions. Any LLM call that touches repo content is followed by a deterministic structural gate before XSM takes action on its output.
Why: The largest injection surface in a coding swarm is the repo itself. An agent that reads adversarial content and forwards it to the coordinator as a command has bridged the trust boundary.

**1.4 Deterministic infrastructure, not model intelligence, is the coordination primitive.**
XSM makes coordination decisions via deterministic state reads and rule evaluation — not by asking a model what to do. Models write code; infrastructure decides what happens next.
Why: LLM judgment is opaque, inconsistent under load, and not auditable. The infrastructure is the product; model capability is the raw material.

---

### 2. Ownership and Authority

**2.1 One fact, one authority.**
Every state fact has exactly one authoritative source, one writer, and a defined violation response. No fact is simultaneously authoritative in two places.
Why: Authority ambiguity is the root cause of split-brain, stale decisions, and irreconcilable state after crash. Conflicts are resolved by the authority map, not by negotiation.

**2.2 One bead, one agent, one worktree.**
The triple (bead-id, agent-id, worktree-path) is enforced as a unique constraint in SQLite. No bead is assigned to more than one agent. No agent holds more than one bead. No worktree is shared.
Why: Shared ownership produces conflicting commits, duplicate PRs, and race conditions that cannot be detected until damage is done.

**2.3 Fencing epochs make stale agents harmless.**
Every external action (git push, PR creation, tmux injection, bead state write) carries the fencing epoch at the time of agent spawn. XSM rejects any action whose epoch does not match the current epoch. A crashed and restarted swarm increments the epoch.
Why: Zombie agents from a prior epoch cannot corrupt state in the current epoch. The epoch is the mechanism that makes recovery safe to automate.

**2.4 No production credentials in agent execution contexts.**
Credentials needed for CI, deployment, or external services are never injected into agent workspaces. Agents operate with repository-scoped tokens only. CI/workflow changes that touch credential access require mandatory human review.
Why: Agent-written code is untrusted output. An agent that can write a test that exfiltrates a credential it has access to has already exfiltrated it.

---

### 3. Work Lifecycle

**3.1 A bead transitions through exactly one path: OPEN → ASSIGNED → ISOLATED → ACTIVE → REVIEWING → VERIFYING → RESOLVED.**
Side exits are BLOCKED_ESCALATE (human needed) and FAILED (non-recoverable). No state is skipped. No state is revisited except via explicit re-assignment from OPEN.
Why: A linear state machine with enumerated exits is auditable. Skipped states hide the failure that caused the skip.

**3.2 Admission is gated by downstream absorption capacity.**
XSM does not assign a new bead to a new coder agent when the VERIFYING backlog exceeds the defined threshold. The swarm slows at the source before it chokes at the drain.
Why: Coders outproducing review capacity generates a queue that degrades every downstream step. The slowest station determines throughput; adding coders before fixing review adds only churn.

**3.3 QA approval is content-addressed to the exact commit SHA.**
A QA pass on commit A is invalidated automatically if the branch is rebased or amended to commit B. VERIFYING cannot proceed on stale approval.
Why: Review detachment — where the approved artifact and the shipped artifact differ — is a silent correctness failure. Content-addressing closes the gap structurally.

**3.4 The landing queue is serialized per dependency graph.**
Only one bead per dependency group is in VERIFYING at a time. Merge ordering is determined before the queue runs, not during.
Why: Parallel landings in the same dependency zone produce rebase cascades that grow super-linearly with PR count. Serialization is slower and safe; parallelism is faster and fragile.

**3.5 CI and workflow changes require mandatory human review.**
Any bead whose diff touches `.github/workflows/`, CI configuration, dependency lock files, or credential access paths is flagged and cannot exit REVIEWING without a human reviewer explicitly acknowledging the flag.
Why: These files are the highest-leverage injection point for supply chain attacks. A coding agent that modifies CI config is modifying the trust boundary of the entire pipeline.

---

### 4. Agent Lifecycle

**4.1 Worktrees are fully ephemeral.**
When an agent crashes, its worktree is deleted and recreated from the latest clean commit. Repair of a corrupted worktree is never attempted.
Why: Partial git states (index locks, mid-rebase HEAD, unstaged changes) are complex to diagnose and unsafe to resume. A fresh worktree from a known-good commit is always cheaper and more reliable.

**4.2 The wrangle ladder is monotonic and structurally terminal.**
XSM escalates through: nudge → inject objective + diff context → BLOCKED_ESCALATE. After 3 wrangle cycles without evidence of gate passage, the bead moves to BLOCKED_ESCALATE unconditionally. The counter does not reset on activity — only on verified gate passage.
Why: An advisory wrangle limit that can be reset by superficial activity (file touches, terminal output) is not a limit. Three cycles without gate passage is the definition of a stuck agent, not an approximation of it.

**4.3 Split-brain detection triggers quarantine before action.**
On restart, XSM takes a live tmux census before reading SQLite. Any agent present in the live census but absent from SQLite (or vice versa) is quarantined — isolated from further assignment — until the discrepancy is resolved. Quarantined agents are not terminated; they are held for inspection.
Why: Killing a live agent without understanding why it exists risks destroying valid work. Quarantine preserves evidence while preventing the agent from taking further action.

---

### 5. Quality and Verification

**5.1 Progress is evidence-bound.**
Forward progress is defined as: a new commit that passes lint, a test suite state change, or a PR status transition. File system modifications, terminal output, and tmux activity are not evidence of progress.
Why: Agents can generate activity indefinitely without producing a shippable artifact. Evidence-bound progress is the only definition that cannot be gamed by a looping agent.

**5.2 QA operates on five layers: structural gates, integration verification, human review, adversarial spot-checks, and rollback capability.**
Each layer has a defined owner and rejection path. No layer substitutes for another. Human review cannot be waived because structural gates passed.
Why: Layered QA catches failure modes that individual layers miss. Structural gates miss semantic issues; human review misses scale; integration verification misses environment drift. The layers are complementary, not redundant.

**5.3 The evidence quality threshold is defined with examples, not adjectives.**
"Sufficient evidence" for a state transition is specified as a concrete artifact type (e.g., passing test run output, lint report with zero errors, diff within defined line-count threshold) — not as "adequate progress" or "reasonable confidence."
Why: Vague thresholds are evaluated inconsistently across agents and reviewers. Concrete artifact types are checkable by a script.

---

### 6. Budget and Resource Control

**6.1 Budget is tracked at the projection boundary, not per agent.**
Token consumption, wall-clock time, and action count (nudges, pushes, PR creations) are aggregated at the XSM level. Per-agent budgets are soft limits; the projection budget is a hard stop.
Why: An agent that stays under its per-agent budget while XSM spawns 20 agents has still blown the projection budget. The boundary that matters is the one closest to the resource.

**6.2 Budget exhaustion stops work; it never relaxes gates.**
When the projection budget is exhausted, XSM halts new assignments and in-progress agents quiesce at their next safe checkpoint. No gate — human review, QA approval, fencing epoch — is bypassed because the budget is running out.
Why: Budget pressure is a social engineering vector. A system that relaxes its strongest controls under resource pressure is weakest exactly when an adversary would apply the most pressure.

**6.3 Admission incorporates financial projection at the bead level.**
Before assigning a bead, XSM estimates the token cost based on bead complexity signals and remaining projection budget. Beads that would exceed remaining budget are not assigned until budget is replenished.
Why: Starting a bead that cannot complete wastes the partial work and leaves the worktree in a state that requires cleanup. Admission-time projection prevents orphaned partial work.

---

### 7. Failure Handling and Recovery

**7.1 Recovery sequence is: census first, reconcile second, quarantine mismatches.**
On any restart, XSM: (1) enumerates live infrastructure (tmux sessions, worktrees, open PRs), (2) reconciles against SQLite state, (3) quarantines any mismatch, (4) resumes only confirmed-clean beads. The sequence is always the same and always produces the same result given the same inputs.
Why: Idempotent recovery means the recovery procedure can be run safely multiple times. A non-idempotent recovery procedure cannot be automated safely.

**7.2 Worktree corruption on crash is resolved by deletion, not repair.**
Git index locks, partial rebases, and unstaged changes from a crashed agent are cleared by deleting the worktree directory and recreating from the last clean commit on the bead's branch. Repair attempts are not made.
Why: The state space of a partially-corrupted git worktree is large and the safe subset is small. Deletion and recreation is O(1) in complexity regardless of how the corruption occurred.

**7.3 A merge bomb halts the landing queue until human review.**
Three or more simultaneous rebase conflicts in the landing queue trigger an immediate halt of all VERIFYING transitions. No further PRs are merged until a human reviews the conflict pattern and clears the queue.
Why: Cascading rebase conflicts are a signal that the dependency graph was wrong or that a foundational change is conflicting with everything built on top of it. Continuing to land into a broken merge state compounds the damage.

---

### 8. Reporting Contract with Nucleus

**8.1 XSM emits typed status events; it does not accept commands through the status channel.**
Projection outputs to nucleus are observations and proposals in a defined event schema. The nucleus interface is one-way for orchestration authority: nucleus dispatches work in; XSM reports state out. Responses to nucleus events are routed through XSM's dispatch handler, not the status channel.
Why: A bidirectional status channel collapses the authority boundary between projection and nucleus. Typed unidirectional events are auditable and cannot be used to inject orchestration instructions.

**8.2 The reporting contract covers exactly: active agent count, bead states, budget consumed, escalations pending, and last-verified commit SHA.**
No other information crosses the projection boundary in the status channel. Agent-internal state, intermediate artifacts, and LLM outputs are projection-internal.
Why: Minimal reporting surface limits what an adversary can infer about swarm internals from the nucleus side and prevents the status channel from becoming a side channel for exfiltration.

---

## Authority Map

| Fact | Authority | Write Rule | Violation Response |
|---|---|---|---|
| Agent leases (who holds what bead) | SQLite `leases` table | XSM only, fencing epoch required | Reject write, quarantine agent |
| Task state (bead lifecycle) | Bead store (beads DB) | XSM only via typed transition | Reject write, log conflict |
| Code and artifacts | Git (worktree + remote) | Agent writes to own worktree; XSM pushes branch | Reject cross-worktree write |
| Events and audit log | Append-only event log | Any component may append; none may update or delete | Alert on delete attempt |
| Budget consumed | XSM projection counter | XSM only, incremented on each metered action | Halt swarm on exhaustion |
| Credentials | Projection secrets store | Never written by agents; injected at projection spawn | Kill agent, revoke projection |
| Merge approval | GitHub PR review / auto-merge | Per merge-mode config; content-addressed to commit SHA | Invalidate on tree change |

---

## Work Lifecycle State Machine

```
OPEN
  |
  | [XSM assigns bead, lease written to SQLite]
  v
ASSIGNED
  |
  | [worktree created, branch isolated]
  v
ISOLATED
  |
  | [agent spawned, objective injected]
  v
ACTIVE ─────────────────────────────────────> BLOCKED_ESCALATE
  |        [3 wrangle cycles, no gate passage]     (human needed)
  | [agent pushes branch with passing lint]
  v
REVIEWING ──────────────────────────────────> FAILED
  |        [human rejects, cannot recover]         (non-recoverable)
  | [human review passes, SHA recorded]
  v
VERIFYING
  |
  | [CI passes, QA approval verified against SHA, merge gate cleared]
  v
RESOLVED
```

State exit rules:
- ACTIVE → BLOCKED_ESCALATE: 3 wrangle cycles without gate passage (structural, not advisory)
- REVIEWING → FAILED: human reviewer marks unrecoverable, or SHA-invalidated approval cannot be refreshed
- Any state → FAILED: fencing epoch violation, budget exhaustion, kill condition triggered

---

## Agent Lifecycle State Machine

```
SPAWN
  |
  | [worktree created, epoch stamped, objective injected]
  v
MONITOR ─────────────────────────────────────> QUARANTINE
  |        [present in census, absent from SQLite]    (hold for inspection)
  | [activity detected, evidence checked]
  v
WRANGLE
  |
  | [nudge / inject context / BLOCKED_ESCALATE]
  |
  +── [gate passage confirmed] ──> MONITOR (reset wrangle counter)
  |
  | [3 cycles without gate passage]
  v
BLOCKED_ESCALATE ──> [human resolves] ──> MONITOR or TERMINATE
  |
TERMINATE
  |
  | [worktree deleted, lease released, epoch invalidated]
  v
  (done)
```

QUARANTINE: Agent is isolated from new assignments. Existing worktree is preserved for inspection. XSM does not inject into a quarantined agent. Human or operator must explicitly clear or terminate.

---

## Kill Conditions

The following conditions trigger an immediate halt of the entire swarm. All in-progress agents quiesce at their next safe checkpoint. No new assignments are made. Operator acknowledgment is required to resume.

1. **Budget exhaustion.** The projection budget (tokens, wall-clock time, or action count) reaches its hard limit. The swarm stops; gates do not relax.

2. **Split-brain / fencing epoch violation.** An action is received with a stale fencing epoch, or the live census and SQLite state cannot be reconciled within the defined window. Indicates zombie agents or corrupted lease state.

3. **Prompt injection quarantine triggered.** A deterministic gate after a repo-content-touching LLM call rejects the output as a suspected injection attempt. The bead is quarantined; the swarm pauses for inspection.

4. **Merge bomb detected.** Three or more simultaneous rebase conflicts in the landing queue. The dependency graph is broken or a foundational change is in conflict. No further landings until a human reviews the conflict pattern.

5. **No forward progress within TTL / operator revocation.** The swarm has not produced a gate passage event within the defined TTL window, or the operator has explicitly revoked the projection. Either condition triggers a full halt.

---

## Residual Risks

These risks survive all controls in v1 and require ongoing attention:

**1. Human reviewer as weakest link.**
The human merge gate is the final defense against semantic attacks that pass structural gates. Reviewer fatigue, complexity overload, and social engineering (e.g., a PR that conceals a malicious change in a large diff) reduce the gate's effectiveness. Mitigation: complexity-gated cooling periods, PR size limits, and rotation policies — but these are partial controls, not elimination.

**2. Epoch race window at spawn boundary.**
There is a window between the moment a new fencing epoch is issued and the moment all prior-epoch agents have been terminated where both epochs are live. An action from a prior-epoch agent that arrives after the new epoch is issued but before rejection logic is applied could slip through. Mitigation: epoch validation before action execution; quarantine on mismatch — but the race window cannot be reduced to zero in a distributed system.

**3. Semantic attacks that pass structural gates.**
A prompt injection payload embedded in repo content may produce code that appears syntactically correct, passes lint and tests, and receives human approval — while containing logic that executes maliciously at runtime. Structural gates check structure, not semantics. Mitigation: human review, CI sandboxing, network egress gating — but semantic review at scale remains an unsolved problem.

---

## v1 Scope Cuts

The following items were explicitly deferred from v1:

- **Repertoire bridge / `diagnose_idle` in orchestration path.** The routine ingests repo content and passes it to an LLM in the orchestration context. This is an injection vector. Cut until a structural gate can be placed between ingestion and any LLM call that influences XSM decisions.

- **Cross-model adversarial review.** Routing agent output to a second model for adversarial review adds complexity without eliminating the semantic gap. The required human reviewer provides equivalent (and more accountable) coverage in v1. Defer to a future phase with defined evaluation criteria.

- **9-state agent classification reduced to 6 states.** `idle_prompt` and `stalled` are merged into IDLE. `crashed` and `orphaned` are merged into ZOMBIE. The 9-state model adds resolution without changing any decision XSM makes in v1.

- **LLM processing of leader inbox content.** The inbox is append-only JSONL. Routing inbox content to an LLM for interpretation creates an injection surface. XSM reads the inbox with a deterministic parser in v1.

- **Financial projection at admission.** Budget-aware admission is deferred to a follow-on bead. v1 enforces projection-boundary budget exhaustion as a kill condition; per-bead cost estimation is not required for the kill condition to work correctly.

---

## Ship First

**Fencing epochs + SQLite unique constraints** are the lock server that every other principle depends on. Implement these first. The epoch invalidation path, the lease uniqueness constraint, and the quarantine-on-mismatch logic are the minimum viable safety foundation. Everything else — the wrangle ladder, admission control, the landing queue — layers on top and inherits its safety properties from the lock server.

---

## Definition of Done

This document is ready for implementation reference when:

- [ ] Each principle has a named enforcement owner, a defined rejection path, and at least one test that fails when the principle is violated.
- [ ] The authority conflict resolution protocol is explicit: when two authorities disagree, which wins, and what is the escalation path.
- [ ] The evidence quality threshold for each state transition is defined with at least one concrete artifact example (not an adjective).
- [ ] Recovery drills pass for the known failure set: crash during ACTIVE, split-brain on restart, merge bomb, budget exhaustion mid-bead.
- [ ] A human reviewer has read and acknowledged this document before any swarm coordination code ships.
