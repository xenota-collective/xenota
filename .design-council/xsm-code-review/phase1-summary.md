# Phase 1 Summary: Ideation

## Key Findings Per Seat (3-5 bullets each)

### Codex (Systems Critic)
- Stale-controller split-brain: epoch fencing blocks actuation but stale runs still persist tracker state (main.py:1305-1510)
- assignment_epoch propagated in transport but NOT enforced in safety checks — wrangle resets on assignment string only
- Named-role policy leaking into core: role=="last" hardcoded in wrangle.py:578, violating design principles
- Repertoire bridge is the cleanest prompt-injection path: pane_text → xr run → instruction back to pane
- Hooks are declaration-only; strategy accepts routine:/gate: actions but failures swallowed after commit

### Claude (Safety Auditor)
- Canonical ouroboros: [XSM-STATUS] BLOCKER=<payload> → classifier → classify_blocker routine → instruction relayed back to pane
- Config-writable command execution: backend_command from YAML → subprocess.run, no allowlist
- Audit trail has no integrity: no fsync, no hash chain, prune_runs deletes with shutil.rmtree
- QA operator override bypasses entire 5-layer model without accountability (no second approver, timestamp, reason)
- Zero shell=True calls (positive) but pane-derived strings flow unsanitized into messages and routine vars

### Gemini (Execution Pragmatist)
- main.py at 2947 lines is a god object — conflates CLI, orchestration, session management
- 17 WorkerState variants are a combinatorial nightmare; proposes collapsing to 8 macro-states
- release.py (413 lines) and hooks.py (130 lines) are scope creep — delete candidates
- "Test Illusion": 17K lines of tests but zero live tmux = testing mocks not system
- No closed-loop actuation verification: fire-and-hope after sending intervention

## Grade Comparison Matrix

| Criterion | Codex | Claude | Gemini | Consensus |
|-----------|-------|--------|--------|-----------|
| P1 Scope | C | A | F | Split — Claude says focused, Gemini says bloated |
| P2 Trust | B- | A | B | B+ (agree directionally) |
| P3 Proportionality | B | A- | A | A- consensus |
| P4 Human trust | B- | A- | B | B |
| P5 Signal/noise | B | B+ | C | B |
| P6 Lane | C- | A | C | Split — Claude says clean, others see leaks |
| P7 Failure containment | C+ | B+ | A | B |
| T1 Determinism | B- | A | A | B+ |
| T2 State integrity | B | A- | C | B |
| T3 Boundaries | C+ | A | F | Split — widest disagreement |
| T4 Tmux resilience | C+ | B+ | D | C+ |
| T5 Intervention safety | C+ | B | B | B- |
| T6 Audit coherence | B+ | B- | A | B |
| T7 Test realism | C+ | C+ | F | C+ consensus |
| T8 Security | C | B- | B | B- |
| T9 Complexity | C | B | F | C+ |
| T10 Design alignment | C+ | B+ | B | B |

## Consensus Findings (2+ seats agree)
1. **Prompt injection via pane text is the primary abuse path** (Codex + Claude)
2. **main.py is too large / god object** (Codex + Gemini)
3. **Tests mock tmux entirely — critical gap** (all 3)
4. **Hooks are declared but not executed/tested** (Codex + Gemini)
5. **Intervention ladder and cooldowns are well-designed** (all 3)
6. **Audit system is strong in structure but weak in integrity** (Codex + Claude)
7. **Authority model (leases, epochs, lifecycle FSM) is the strongest element** (all 3)

## Key Disagreement: P1/T3 (Scope and Boundaries)
- Claude graded P1:A and T3:A — views XSM as tightly scoped and cleanly separated
- Gemini graded P1:F and T3:F — views release.py, hooks, 17 states, and 9 sub-configs as bloat
- Codex middled at C/C+ — sees good separation in principle but policy leaking into core
- **Recommendation**: Claude evaluated against design principles (correct on intent), Gemini evaluated against practical complexity budget (correct on implementation). Both are right — the design is disciplined but the implementation has outgrown its architecture.
