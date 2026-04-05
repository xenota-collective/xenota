# XSM Comprehensive Code Review — Design Council Report

**Bead:** xc-l8zq
**Date:** 2026-04-06
**Mode:** Full (4 phases: Ideation, Black Hat, Simplify, Security Signoff)
**Seats:** Codex/gpt-5.4 (Systems Critic), Claude/opus (Safety Auditor), Gemini/3.1-pro (Execution Pragmatist)
**Scope:** xenon/packages/xsm/ — 22 source files (~12K lines), 24 test files (~17K lines)

---

## Verdict: CONDITIONAL GO

**2 of 3 seats: Conditional Go. 1 seat: No-Go (upgradeable to Conditional Go after controls).**

XSM's architecture is sound. The authority model, deterministic-first design, and bounded intervention ladder are better than most production agent coordination systems. However, the gap between the excellent design principles document and the implementation must be closed before production deployment.

**The system is safe to run with human oversight today.** The critical findings are about hardening for autonomous operation.

---

## Consensus Findings (agreed by 2+ seats)

### Strongest Elements (preserve these)
1. **Authority model** — lease-based mutual exclusivity, lifecycle FSM with human gates, control epoch fencing (all 3 seats)
2. **Deterministic classifier** — zero LLM in the decision path, ordered priority rules, reproducible from signals (all 3)
3. **Intervention ladder** — bounded reinvokes, cooldowns, exhaustion latches, structural termination (all 3)
4. **Zero `shell=True`** — every subprocess uses list-form arguments across entire codebase (Claude, Codex)
5. **Append-only audit trail** — JSONL event stream with sequence numbering and schema versioning (all 3)

### Critical Findings (must fix)
1. **Pane text treated as authoritative when untrusted** — the canonical prompt injection ouroboros: pane text → status tuple/blocker → classify_blocker LLM routine → suggested_action → back into pane. Zero validation at any step. (all 3 seats, CRITICAL)
2. **No subprocess timeouts on tmux/git/gh** — a single hung command freezes the entire controller indefinitely. `tmux.py`, `evidence.py`, `actuator.py` all call subprocess.run without timeout. (Codex + Gemini, CATASTROPHIC operational risk)

### High-Priority Findings
3. **Split-brain state persistence** — epoch fencing blocks actuation but stale wrangle passes still persist tracker state to SQLite unconditionally (`main.py:1400`). (Codex, HIGH)
4. **No swarm-level circuit breaker** — `cascade_block_depth` parsed in config but never enforced at runtime. Per-agent cooldowns exist but no global budget. (Codex + Gemini, HIGH)
5. **SQLite no WAL mode** — default rollback journal will crash on concurrent access from monitor + wrangle. (Gemini, SEVERE)
6. **Serial O(N) processing** — 50+ agents = 25+ second loop times, stale classifications. (Codex + Gemini, SEVERE)
7. **Config-writable command execution** — `backend_command` from strategy YAML passed directly to subprocess.run in visualize.py, no allowlist. (Claude, HIGH)

### Product Findings
8. **main.py god object** — 2586 lines mixing CLI, orchestration, session management. (Codex + Gemini)
9. **17 states = combinatorial overhead** — code already collapses to 7 behavioral groups via handler reuse. Formalize this. (all 3)
10. **Hooks, release, repertoire_bridge, visualize are premature** — cut from v1 to reduce attack surface and complexity. (all 3)
11. **Strategy config bloat** — only 3 of 9 sub-configs are load-bearing at runtime. (Codex + Gemini)

---

## Required Controls Before Ship

| # | Control | Severity | Effort | Seats |
|---|---------|----------|--------|-------|
| **RC-1** | Add subprocess timeouts to ALL tmux/git/gh/gt calls | CATASTROPHIC | Hours | Codex, Gemini |
| **RC-2** | SQLite WAL mode + connection timeout | SEVERE | Hours | Gemini |
| **RC-3** | Pane text sanitization boundary (truncate, strip control chars, length bounds) | CRITICAL | 1-2 days | Claude, Codex |
| **RC-4** | Repertoire output content gate (length, charset, no metacharacters) | CRITICAL | 1-2 days | Claude |
| **RC-5** | Epoch fencing on state persistence, not just actuation | HIGH | 1-2 days | Codex |
| **RC-6** | Swarm-level circuit breaker (halt on >50% failure rate) | HIGH | 1-2 days | Codex, Claude, Gemini |
| **RC-7** | Repertoire bridge circuit breaker (3 failures → skip for 5min) | HIGH | 1 day | Claude |

**Estimated total: 1-2 weeks of focused hardening.**

---

## Adopt Now (immediate improvements)

### One-Line Fixes
```python
# tmux.py — add timeout to all subprocess.run calls
subprocess.run(command, timeout=5.0, ...)

# state.py — enable WAL mode on connection
connection.execute("PRAGMA journal_mode=WAL")
connection.execute("PRAGMA synchronous=NORMAL")

# state.py — add connection timeout
sqlite3.connect(path, timeout=10.0)
```

### v1 Module Cuts
- Delete `hooks.py` (130 lines) — declared but never executed
- Delete `release.py` (413 lines) — packaging belongs in CI
- Delete `visualize.py` (587 lines) — UI layer, not core
- Cut `repertoire_bridge.py` (63 lines) from autonomous path — most dangerous injection vector
- Simplify `qa.py` — remove operator_override, all gates must pass

### Trust Boundary Definition
> **XSM trusts only what it wrote (tmux options, SQLite state, audit log) and verifies everything else (pane text, process state, git state) as advisory evidence that can be wrong or adversarial.**

---

## Backlog (defer to v2)

1. **State collapse 17 → 7** with `_kind` subfields (Codex's model matches actual handler reuse)
2. **Split main.py** into 7 domain-specific CLI modules (cli_worker, cli_monitor, cli_lifecycle, cli_leader, wrangle_exec, cli_audit, cli_misc)
3. **Strategy config pruning** — cut 6 dead sub-configs, keep intervention/assignment/bead_policy
4. **Pane text as hint architecture** — reorder classify_worker_state so structured signals outrank regex (Claude's 4-week plan)
5. **Audit integrity chain** — SHA-256 hash chaining, fsync after writes, quarantine instead of delete for prune_runs
6. **Live tmux test harness** — disposable sessions with real capture-pane/send-keys, adversarial fixtures
7. **ThreadPoolExecutor for concurrent agent polling** — O(N) → O(1) per pass
8. **Named tmux buffers per agent session** — prevent cross-agent buffer races
9. **Credential scrubbing** before pane text enters LLM calls or audit logs

---

## Kill Conditions

Trigger emergency shutdown if any occur:
1. Two active leaders or conflicting epochs observed
2. XSM acts on content lacking valid XSM-authored marker
3. Circuit breaker trips repeatedly (intervention rate spike beyond policy)
4. Subprocess exceeds timeout and blocks control decisions
5. Contradictory interventions issued to same target within one control window
6. >50% of agents in failure state simultaneously
7. Audit logs become incomplete, inconsistent, or unavailable

---

## Monitoring Requirements

| Metric | Alert Threshold |
|--------|----------------|
| Wrangle pass duration | > 2x normal |
| Repertoire bridge latency | p95 > 30s |
| Intervention ladder exhaustion rate | > 50% agents exhausted/hr |
| Subprocess timeout rate | Any non-zero |
| Fencing epoch mismatches | Any non-zero |
| Agent state oscillation | > 5 transitions/minute/agent |
| Pane capture matching credential patterns | Any match |

---

## Disagreements

### Scope Discipline (P1)
- Claude: A (design is focused) vs Gemini: F (implementation is bloated)
- **Resolution:** Both right — design principles are disciplined but implementation outgrew architecture. Adopt v1 cuts.

### Module Boundaries (T3)
- Claude: A (clean separation) vs Gemini: F (main.py god object)
- **Resolution:** Boundaries are clean in domain model; main.py violates them. Split is backlog item.

### Pane Text Authority
- Codex: "Pane text should stay primary for liveness"
- Claude: "Pane text should be a hint, not a signal"
- **Resolution:** Both have merit. For v1, pane text remains primary for liveness detection but MUST be sanitized before any external use (LLM calls, messages, audit). v2 migrates to structured channels.

---

## Grade Summary (Phase 1 averages)

| Criterion | Avg Grade | Verdict |
|-----------|-----------|---------|
| P1 Scope discipline | B- | Good principles, trim implementation |
| P2 Deterministic trust | B+ | Core strength |
| P3 Intervention proportionality | A- | Excellent |
| P4 Human trust surface | B | Good, needs stress testing |
| P5 Signal-to-noise | B | Manageable |
| P6 Manager stays in lane | B- | Minor leaks (role=="last") |
| P7 Failure containment | B | Good, needs circuit breaker |
| T1 Determinism | B+ | Core strength |
| T2 State model integrity | B | Good, needs WAL + fencing |
| T3 Module boundary clarity | B- | main.py is the bottleneck |
| T4 Tmux surface resilience | C+ | Regex-heavy, needs sanitization |
| T5 Intervention safety | B- | Good TOCTOU, needs output gate |
| T6 Audit coherence | B | Structure good, integrity weak |
| T7 Test realism | C+ | Critical gap: zero live tmux |
| T8 Security hardening | B- | Good subprocess, weak pane text |
| T9 Complexity hotspots | C+ | main.py, 17 states, 9 configs |
| T10 Design doc alignment | B | Principles ahead of implementation |

---

## Missing Seat Data

- Claude Phase 2 first run was lost (1-line capture). Successfully re-run with `| tee`.
- All other phases captured successfully.

---

## Council Process Notes

Full seat logs, per-phase summaries, and comparative analysis available in `.design-council/xsm-code-review/seat-logs/`.

**Session logs:**
- Codex: `~/.codex/sessions/2026/04/06/` (JSONL rollout files)
- Claude: No persistent session for `-p` pipe mode (captured via tee to working dir)
- Gemini: `~/.gemini/tmp/tmp/chats/` (JSON session files)
