# Phase 3 Summary: Simplify

## Consensus: v1 Module Survival List
All 3 seats agree on what to KEEP and what to CUT:

### KEEP (load-bearing)
- config.py, signals.py, tmux.py, classifier.py, monitor.py
- intervention.py, actuator.py, wrangle.py, audit.py, messages.py
- state.py (authority core — leases, epochs, lifecycle)

### CUT from v1 (all 3 agree)
- **hooks.py** — declared but never executed (Codex, Claude, Gemini)
- **release.py** — packaging belongs in CI, not the runtime (Codex, Gemini)
- **repertoire_bridge.py** — most dangerous pane-text-to-LLM pipeline (Claude, Codex)
- **visualize.py** — UI layer, not core state machine (Codex, Gemini)

### CUT from v1 (2 of 3 agree)
- **qa.py** — cut operator_override, simplify to "all gates must pass" (Claude, Codex)
- **backlog.py** — move out of autonomous path (Codex)

## State Collapse (all 3 agree on direction, differ on count)

| Codex (7 states) | Claude (8 states) | Gemini (8 states) |
|---|---|---|
| active | ACTIVE | RUNNING |
| launching | LAUNCHING | STARTING |
| idle (with idle_kind) | PARKED | IDLE |
| blocked (with blocked_kind) | BLOCKED + RATE_LIMITED | BLOCKED |
| handoff | (merged into PARKED) | HANDOFF |
| ambiguous | AMBIGUOUS | UNKNOWN |
| terminal (with terminal_kind) | DEAD + STOPPED | STOPPED + FAILED |

**Recommendation**: Codex's 7-state model with `_kind` subfields is most elegant — it matches actual handler reuse in wrangle.py:1035.

## main.py Split

| Codex (7 files) | Claude (not proposed) | Gemini (3 files) |
|---|---|---|
| cli_worker.py | — | cli.py |
| cli_monitor.py | — | orchestrator.py |
| cli_lifecycle.py | — | session.py |
| cli_leader.py | — | — |
| wrangle_exec.py | — | — |
| cli_audit.py | — | — |
| cli_misc.py | — | — |

**Recommendation**: Codex's 7-file split is more precise. Gemini's 3-file split is simpler but less granular.

## Strategy Config (9 → 3 load-bearing)
All agree: **intervention**, **assignment**, **bead_policy** are load-bearing. The rest are dead config.

## Trust Boundary (Claude's one-sentence definition, endorsed by all)
> "XSM trusts only what it wrote (tmux options, SQLite state, audit log) and verifies everything else (pane text, process state, git state) as advisory evidence that can be wrong or adversarial."

## 30-Day Recommendations
- Codex: Hardening freeze — observe-only except one canary lane, reject any PR that adds without deleting
- Claude: "Pane text as hint" architecture change — 4-week plan (structured channels → reorder classifier → cut repertoire → circuit breaker)
- Gemini: "XSM 4.5K Core" lockdown — aggressive deletion weeks 1-3, rebuild tests week 4

## Key Disagreement
- Codex says "pane text should stay primary for liveness" — disagrees with Claude's "pane text as hint"
- This is the most consequential design decision: is pane text authoritative or advisory?
