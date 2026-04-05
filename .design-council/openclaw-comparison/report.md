# Design Council Report: OpenClaw vs Xenota Architecture Analysis

**Date**: 2026-03-29
**Mode**: Full (4 phases: Ideation → Black Hat → Simplify → Security Signoff)
**Seats**: Codex GPT-5.4 (Systems Critic), Claude Sonnet (Safety Auditor), Gemini 3.1 Pro (Execution Pragmatist)

---

## Verdict: CONDITIONAL GO

All three seats agree: **Conditional Go** on a narrowed, safety-preserving spec that captures OpenClaw's operational strengths without compromising Xenota's persistent-identity architecture.

---

## The Article: What OpenClaw Actually Demonstrated

Robert Schwentker's article describes OpenClaw running 30 concurrent agents consuming 5B tokens/day, refactoring 1.5M LOC in 7 days. The key architectural patterns:

1. **Config-first agent definition** (SOUL.md, Markdown skills)
2. **Session keys as addresses** (pipeline:project:role = routing + discovery + identity)
3. **Lobster deterministic YAML workflows** (LLM does creative work, YAML does plumbing)
4. **Factory-line role decomposition** (Programmer/Reviewer/Tester with hard capability splits)
5. **Local-first append-only state** (JSONL, no external DB)
6. **Infrastructure as the product** (bottleneck is infrastructure legibility, not model speed)

The article's core insight: **"Boundaries are not constraints on agent capability. Boundaries are the mechanism through which agents achieve coordination."**

---

## Consensus: What Xenota Should Learn

### Where OpenClaw Excels (and Xenota Doesn't Yet)

| OpenClaw Strength | Xenota Gap | Council Assessment |
|---|---|---|
| Cheap, routable addressing | Gas Town roles are semantic-heavy for high-throughput routing | Adopt as cortex-mediated capability aliases, not P2P |
| Deterministic workflow orchestration | Molecules lack typed I/O, retry budgets, timeout semantics | Formalize as validated task presets over existing infrastructure |
| Append-only tracing | No unified trace spine across nucleus/cortex/projections | Build SQLite trace spine as first-class recovery substrate |
| Config-first behavior editing | Repertoire system requires packaging for any capability change | Keep repertoire for critical paths; consider read-only context injection |
| Factory-line role separation | Agent capabilities are implicit from genome, not explicit envelopes | Add capability profiles as governance objects |

### Where Xenota Excels (and OpenClaw Doesn't)

| Xenota Strength | OpenClaw Gap |
|---|---|
| Persistent nucleus identity with continuity | Stateless config-based, no cross-session identity |
| BAR gate + membrane + quarantine safety stack | Per-tool permissions only, no layered safety |
| Authority split (nucleus decides, cortex executes) | Single gateway control plane |
| Repertoire contracts with multi-backend eval | Ad-hoc prompt skills, no formal testing |
| Projection revocation + operator kill switches | No architectural enforcement of trust boundaries |
| XSM deterministic swarm monitoring | Manual intervention for stuck agents |
| Chaperone as privileged separate channel | All access through same gateway |

---

## Disagreements (with Decision Recommendations)

| Topic | Codex (Systems Critic) | Claude (Safety Auditor) | Gemini (Pragmatist) | Decision |
|---|---|---|---|---|
| **JSONL for active work** | Delete as authority source | N/A | Use as volatile L1 cache, flush to SQLite | **Gemini's approach**: JSONL for debug export only, SQLite is authority |
| **P2P messaging** | Delete entirely | Must be architecturally impossible to bypass membrane | Route through sidecar proxy | **Claude's approach**: no unobserved transport, period |
| **Markdown skills** | Delete | Must route through same vetting pipeline as repertoire | Read-only RAG context only | **Gemini's approach**: read-only context injection, never executable |
| **YAML workflow engine** | Delete new engine | Defer until enforcement is proven | Compile YAML to existing formula structures | **Codex's approach**: validated task presets over existing cortex actions, no new engine |
| **TrustContext signing** | Not mentioned | HMAC with short TTL + nonce, must-ship | Not mentioned | **Claude's approach**: required for cortex routing safety |
| **Idempotency invariant** | Must-add: no side effect without durable action ID | Not explicitly stated | Accept replay risk for V1 | **Codex's approach**: add idempotency invariant, it's required for safe recovery |

---

## Adopt Now: The Surviving 30-Day Spec

### Three Changes (in sequence)

**Week 1: SQLite Trace Spine** — GO
- Append-only `events` table in existing nucleus SQLite
- Fields: `{action_id, ts, agent_id, action_type, target_resource, trust_level, delegator, policy_decision, completion_code, schema_version}`
- No UPDATE/DELETE grants in application role
- Trace write is on critical path: if append fails, action is denied
- Recovery rebuilds from SQLite only
- PII separated at write time (opaque references only in operational trace)
- **Success metric**: >95% in-flight work reconstructable after forced SIGKILL; recovery <10s

**Week 2: Cortex-Routed Capability Aliases** — CONDITIONAL GO
- One SQLite table for aliases, versioned and auditable
- Membrane sends `dispatch(alias, payload)` to cortex
- Cortex resolves alias to eligible target using authoritative state + caller ceiling check
- Raw peer addressing rejected at every ingress path
- Resolution decisions logged with alias version and resolved target
- **Conditions**: TrustContext HMAC signing ships with this; capability ceiling enforcement ships with this
- **Success metric**: 100% dispatches through cortex, zero direct peer sends

**Week 3-4: Validated Task Presets** — CONDITIONAL GO
- Typed preset schema validated against repertoire contracts at load time
- Cortex expands into normal routed actions — no loops, no branching, no new executor
- Each expanded step goes through normal routing and per-step authorization
- Hard limits: max steps, max wall time, max fan-out
- Start with 2-3 curated flows only
- **Conditions**: sealed capability registry ships with this; genome mutation gates ship with this
- **Success metric**: 2-3 workflows end-to-end, setup time halved, no contract violations

### Five Must-Ship Safety Items (ship WITH the changes, not after)

1. **Sealed capability registry** — boolean `registry_sealed` flag, set during init, all registration calls check it. Ships with Change 3.
2. **Capability ceiling enforcement** — immutable spawn-time assignment, membrane intercepts all capability checks. Ships with Change 2.
3. **TrustContext HMAC signing** — HMAC over {claim, agent_id, timestamp}, short TTL (≤10s), nonce, membrane-verified. Unsigned = rejected. Ships with Change 2.
4. **Genome mutation gates** — synchronous, blocking, no self-approval, gate event written to audit log. Ships with Change 2.
5. **Minimal ActionIntent audit record** — the trace spine IS this item. Ships as Change 1.

### One Missing Invariant (add to spec)

> **No irreversible external side effect may execute unless it has a durable action ID recorded in SQLite first, and executors must enforce idempotency on that action ID.**

Without this, SQLite-only recovery creates duplicate-action vulnerabilities.

---

## Killed: What NOT to Build

| Proposal | Reason for Kill |
|---|---|
| Direct P2P agent addressing | Creates unobservable coalitions, bypasses membrane |
| JSONL as authority/recovery source | Split-brain with SQLite, crash recovery ambiguity |
| Markdown executable skills | Bypasses repertoire contract enforcement, untestable prompt injection |
| New workflow engine / DAG runner | Two engines = split-brain operator confusion |
| Factory-line role templates as primary model | Jams on cross-cutting work, contradicts persistent identity |
| Config-defined authority rules | Config may only parameterize already-approved contracts |
| "Tokens/day" as success metric | Incentivizes runaway loops; use "resolved beads per hour" |

---

## Backlog: Defer to V2

| Item | Why Defer | Condition for Safe Deferral |
|---|---|---|
| Full retention policies | Solve PII separation structurally now; policy layer follows | PII fields must be structurally separated in log schema before deferral |
| Verbose ActionIntent logging | Noise can be weaponized; minimal record ships instead | Must not be added as "temporary measure" |
| YAML workflow authoring | Convenience only; high injection surface | Defer until enforcement is proven solid |
| Cross-boundary trust protocol | OpenClaw acknowledges this is unsolved; Xenota shouldn't rush it | Projection revocation + membrane provide interim coverage |
| Cortex process isolation | Cortex is single point of compromise | Monitor Cortex CPU/memory; architect isolation for V2 |
| Log hash anchoring | File-level SQLite tampering remains possible | Periodic hash to out-of-process store |
| Enumeration rate limiting on alias discovery | Topology leakage via repeated "who can do X" | Namespace scoping provides interim coverage |

---

## Kill Conditions (Stop and Roll Back If...)

- Any routed action completes without a durable trace row
- Recovery rebuild diverges from live state
- PII appears in the operational trace
- A direct peer identifier is accepted on the routed surface
- Alias resolution leads to execution the caller could not otherwise obtain
- A preset executes a step the invoker could not issue directly
- Crash/replay causes duplicate external side effects

---

## Key Insights from the Council

### The Core Tension (Codex)
> "What fails first in Xenota is not identity or safety. It is coordination entropy: too many rich concepts, not enough cheap addressing, deterministic workflowing, and replayable traces to run a large swarm without human babysitting."

### The Safety Principle (Claude)
> "Every informal/lightweight path must enforce the same invariants as the formal path, or the formal path's guarantees are meaningless."

### The Pragmatic Cut (Gemini)
> "Tokens/day is a vanity metric; throughput of resolved beads is the only metric that matters."

### The Authority Warning (Codex, after source analysis)
> "Adopt cheap addressing, append-only traces, and role templates only as adjuncts under nucleus/cortex authority, never as replacement authority."

### The Governance Bottom Line (Claude)
> "The governance risk in this system is not missing rules — it's missing enforcement. Every deferral is safe only because the must-ship items close the corresponding attack surface first. Reverse the order and none of the deferrals hold."

---

## Pre-Deployment Safety Checklist

```
SCHEMA & DATA INTEGRITY
[ ] SQLite trace table has no UPDATE/DELETE grants in application role
[ ] File permissions: application user write, no world-read
[ ] action_type and target_resource cannot encode PII (review enum/string constraints)
[ ] ActionIntent records written synchronously before action returns
[ ] Idempotency keys enforced on all irreversible external side effects

ROUTING & TRUST
[ ] HMAC key loaded from secure config, not embedded in code
[ ] TrustContext TTL ≤10s, enforced
[ ] Nonce uniqueness enforced server-side
[ ] Cortex rejects any dispatch missing valid signed TrustContext

CAPABILITY CONTROLS
[ ] Capability ceiling assigned at spawn, stored immutably (no setter after construction)
[ ] Cortex routing enforces ceiling check before alias resolution
[ ] Registry seal flag set before untrusted content loads
[ ] Seal flag has no unseal path at runtime

MUTATION GATES
[ ] Genome mutation gate is synchronous and blocking
[ ] Self-approval explicitly rejected (tested)
[ ] All mutation attempts written to audit log regardless of outcome

INTEGRATION TESTS
[ ] Routed action → ActionIntent record with correct fields
[ ] Preset loaded before seal, content after seal → no new capabilities
[ ] Dispatch with expired TrustContext → rejected at membrane
[ ] Agent attempts action above ceiling via alias → rejected, logged
[ ] SIGKILL under load → >95% recovery from SQLite in <10s

DEPLOYMENT
[ ] Checklist reviewed by someone not on implementing team
[ ] Rollback procedure tested
[ ] Monitoring alerts for audit log write failures
```

---

## Governance Documentation Required Before Go-Live

1. **Capability Authority Policy** — what capabilities exist, who grants them, root trust anchor, ceiling inheritance rules
2. **TrustContext Specification** — HMAC algorithm, TTL ceiling (hard number), nonce format, validation failure behavior (versioned document)
3. **Audit Log Retention & Access Policy** — who reads, retention period, review triggers, log write failure notification
4. **Sealed Registry Change Procedure** — unseal → modify → reseal cycle, authorization requirements
5. **Incident Response for Trust Violations** — definition, notification, containment, evidence preservation
