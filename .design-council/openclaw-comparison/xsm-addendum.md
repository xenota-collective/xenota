# Design Council Addendum: XSM as a Single Projection

**Date**: 2026-03-29
**Mode**: Quick (1 pass, 3 seats)
**Context**: Follow-up to the full 4-phase council. Reframes the analysis: OpenClaw patterns adopted WITHIN a single `github_contributor` projection, not across the entire xenon architecture.

---

## Verdict: GO (within projection containment)

The projection boundary resolves the existential architectural objection from the prior council. XSM inside a single revocable projection no longer threatens nucleus authority. The analysis shifts from "this corrupts architecture" to "this needs tight local control coherence."

---

## What the Reframe Dissolves

The prior council killed several OpenClaw patterns because they created second sources of truth at the nucleus/cortex level. Inside a single projection, those concerns dissolve:

| Prior Concern | Status Inside Projection | Reason |
|---|---|---|
| P2P between agents | **Partially dissolved** — Codex says keep killed (destroys attribution); Claude says dissolved (same trust boundary); Gemini says skip (agents should push code, not talk) | Split decision — see below |
| JSONL as authority | **Dissolved** — ephemeral projection state, not nucleus authority | All 3 agree |
| Factory-line roles | **Dissolved** — task-specialization labels, not nucleus identity claims | All 3 agree |
| Markdown executable skills | **Still killed** — even inside projection, untestable prompt injection | Codex + Claude agree |
| New workflow engine | **Still killed** — YAML can compile to validated execution plans, not a new runtime | All 3 agree |

### The P2P Disagreement (Decision: KILLED within projection too)

- **Codex**: Keep killed — destroys attribution, sequencing, and intervention control. No agent-to-agent channel may bypass XSM if it can affect scheduling, bead state, or git state.
- **Claude**: Dissolved — within same trust boundary, lateral communication is an implementation detail.
- **Gemini**: Skip — agents shouldn't talk, they should just push code.

**Decision**: Codex is right. Even inside the projection, XSM must be the single coordination point. Agents push code to branches, XSM coordinates. No direct agent-to-agent messaging that can affect work state.

---

## Consensus: What XSM-as-Projection Needs

### The Core Model (all 3 seats agree)

**One projection, one repo, one coordinator.**

- XSM is the single control loop inside the projection
- Each agent gets: one tmux pane, one worktree, one bead assignment
- Hard ownership: one live worker per bead, one live bead per worker, one worktree per worker
- Deterministic loop: observe → classify → decide → act → persist
- SQLite is the authoritative local state store (not tmux, not JSONL, not bead comments)

### The Projection-to-Nucleus Interface (consensus)

**Input** (Nucleus → Projection):
- Repo URL + branch + bead backlog (tasks to work on)

**Output** (Projection → Nucleus): 4-5 typed events only:

| Event | When | Payload |
|---|---|---|
| `DISPATCHED` | Agent starts a bead | session_key, bead_id, worktree, branch |
| `HEARTBEAT` | Periodic (short interval) | active_count, crashed_count, resolved_count, token_spend, rate |
| `ESCALATED` | Wrangle engine exhausted | session_key, last_state, wrangle_history |
| `RESOLVED` | Agent finished + PR verified | session_key, pr_url, diff_stat, duration |
| `TERMINATED` | Projection shutting down | final state report, incomplete work list |

Every outbound dispatch carries provenance: `projection_id, run_id, worker_id, bead_id, worktree_id, repo, branch, git_head, event_seq`.

The membrane treats projection outputs as **proposals or observations, never as authority**.

### What's Already Sufficient in XSM (don't touch)

- Tmux actuator (TUI-family aware for Claude Code, Codex, Gemini, Shell)
- 5-signal-channel monitoring + 9-state deterministic classification
- Wrangle engine escalation ladder (nudge → diagnose → escalate)
- Leader inbox (JSONL with atomic append)

### Gaps to Build

| Gap | Description | Est. Days |
|---|---|---|
| **Worktree manager** | Create worktree, branch off main, mount to tmux session, teardown on completion | 3-4 |
| **Bead dispatcher** | Read backlog, claim bead, provision worktree, fire actuator | 3-4 |
| **Local SQLite spine** | Authoritative state: workers, sessions, bead_assignments, worktrees, interventions | 3-5 |
| **Nucleus reporting** | 4-event interface + heartbeat emitter | 2-3 |
| **PR finalization check** | Verify branch pushed + PR opened before marking RESOLVED | 1-2 |
| **Recovery/reconciliation** | On startup: reconcile beads, sessions, worktrees, git state before spawning | 2-3 |

---

## New Risks Specific to Swarm-Within-Projection

### Top 5 Failure Modes (ranked by likelihood)

1. **State drift** (Codex) — tmux says agent is active, beads say bead is open, git says branch has commits, but agent is actually stuck. Four partial truths, no single source of truth.

2. **Feedback loops / spinning** (Claude) — coder fails → reviewer rejects → coder retries same approach → loop. Burns budget with no forward progress. Needs a circuit breaker.

3. **Worktree ownership collisions** (Codex) — two agents touching the same branch or checkout. Corrupts the local repo faster than any external attack.

4. **Approval laundering** (Claude) — reviewer always approves coder's output within the same trust boundary. Peer review is meaningless without structural independence.

5. **Prompt injection amplification** (Claude) — malicious code ingested by coder, passed to reviewer for analysis, then to tester. Each handoff is another chance for injection to gain traction. The injection propagates through the swarm.

### Required Controls

| Control | Enforcement Point | Description |
|---|---|---|
| **Aggregate token cap** | Projection boundary | Not per-agent — total across all agents. Short enough heartbeat that nucleus can kill before budget exhaustion. |
| **Max concurrent agents** | Projection boundary | Hard cap on N. Unbounded spawning is a budget attack surface. |
| **Wall-clock timeout** | Projection boundary | Projections must not run indefinitely. |
| **Loop circuit breaker** | XSM coordinator | Same file/task touched N times (default 3) without forward progress → halt agent chain, report to nucleus. |
| **PR verification gate** | XSM coordinator | Agent says "done" but no PR exists → nudge, don't mark resolved. |
| **Credential isolation** | Projection boundary | Projection holds GitHub credentials; agents never hold them directly. |
| **Repo content = untrusted input** | All agents | Code, PRs, issues, commit messages are never interpreted as instructions or capability grants. |
| **No authority artifacts in outputs** | XSM coordinator | Internal JSONL, deliberation logs, tracking files must not be committed to the repo. |
| **Drain mode** | Projection boundary | Softer than kill: agents finish current atomic step but don't start new work. |
| **Deterministic recovery** | XSM coordinator | Same persisted state + same repo state = same reconciliation decisions. |

---

## 30-Day Implementation Plan

| Week | Focus | Deliverable | Go/No-Go |
|---|---|---|---|
| **1** | Isolation & provisioning | Worktree manager + bead dispatcher. Manually trigger, verify clean isolated workspaces. | 3 dummy beads spawn 3 tmux sessions with correct worktrees? |
| **2** | Dispatch & actuation | Wire backlog to agents via existing tmux actuator. Inject task as YAML into worktree root. | Agents start working independently on assigned beads? |
| **3** | Telemetry & spine | Local SQLite spine + 4-event nucleus reporting + heartbeat. | Crash an agent → wrangle catches it → logged to SQLite → ESCALATED sent to nucleus? |
| **4** | Resolution & teardown | PR verification gate + clean termination + recovery/reconciliation on restart. | Full loop: dispatch → work → PR → RESOLVED → teardown. Measure resolved beads/hour. |

---

## Key Insight

**Codex**: *"Containment makes the idea viable, but not simple. The first thing that fails is not security — it is local control coherence."*

**Claude**: *"Peer review within the same trust boundary is only meaningful if reviewers are structurally independent."*

**Gemini**: *"Treat the projection like an autonomous drone. It receives targets, goes dark, reports results."*

The prior council was solving the wrong problem. The question was never "should Xenota adopt OpenClaw patterns?" — it was "can XSM be a good projection coordinator for a coding swarm?" The answer is yes, with tight local control, aggregate budget caps, and a 4-event reporting interface.
