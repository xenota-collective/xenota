# Phase 2 Summary: Black Hat

## Key Findings Per Seat (3-5 bullets each)

### Codex (Systems Critic)
- CRITICAL: Pane text control-plane spoofing — any [XSM-STATUS] line is trusted, newest wins, flows into landing queue generation
- CRITICAL: Repertoire prompt injection — raw pane_text → classify_blocker prompt.md:10 → suggested_action → back into pane
- HIGH: Split-brain — stale wrangle persists tracker state even after epoch rejects actions
- HIGH: No swarm-level escalation circuit breaker — cascade_block_depth parsed but never enforced
- DB corruption fails open: _prepare_db_path deletes non-SQLite files = silent amnesia

### Claude (Safety Auditor)
- [RE-RUNNING — only got summary: canonical ouroboros via pane text → LLM → pane is the critical finding]

### Gemini (Execution Pragmatist)
- CERTAIN/CATASTROPHIC: Tmux subprocess.run has NO timeout — hangs forever on tmux server lockup
- LIKELY/SEVERE: SQLite no WAL mode, no connection timeout — crashes on concurrent access
- CERTAIN/SEVERE: Synchronous O(N) loop — 50s per pass at 100 agents, stale classifications
- CERTAIN/SEVERE: InterventionTracker not persisted across restart — split-brain on upgrade
- Proposed 3 one-line fixes for the most catastrophic operational failures

## Consensus Findings (2+ seats agree)
1. **Pane text is untrusted but treated as authoritative** — all seats agree this is the primary attack surface
2. **No subprocess timeouts on tmux/git** — Codex and Gemini both found this independently
3. **Serial processing creates scaling bottleneck** — Codex and Gemini agree
4. **Split-brain on restart/stale controller** — Codex (state persistence) and Gemini (tracker loss) agree
5. **No swarm-level budget/circuit breaker** — Codex found, Gemini's scaling concern is related

## Severity-Ordered Action List
| Priority | Finding | Severity | Fix Complexity |
|----------|---------|----------|----------------|
| 1 | Pane text sanitization boundary | CRITICAL | Medium — add sanitize_pane_text() at extraction points |
| 2 | Repertoire returns enums not freeform text | CRITICAL | Medium — change routine schemas + XSM templates messages |
| 3 | Subprocess timeouts on all tmux/git/gh calls | HIGH | Low — 1-line timeout= additions |
| 4 | SQLite WAL mode + connection timeout | HIGH | Low — 2-line PRAGMA additions |
| 5 | Epoch fencing on state persistence, not just actuation | HIGH | Medium — guard save_state with epoch check |
| 6 | Swarm-level escalation circuit breaker | HIGH | Medium — add global budget to wrangle_pass |
| 7 | DB corruption quarantine instead of delete | HIGH | Low — rename instead of unlink |

## 30-Day Recommendations (per seat)
- Codex: Adversarial live-tmux CI harness (forged status lines, stale epochs, hung subprocesses)
- Claude: [pending re-run]
- Gemini: ThreadPoolExecutor for concurrent agent polling (O(N) → O(1))
