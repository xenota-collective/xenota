# Phase 2 (Black Hat) — Codex (Systems Critic)
**Model**: gpt-5.4, reasoning_effort=high
**Tokens used**: 167,666
**Session log**: Check ~/.codex/sessions/2026/04/06/ for latest rollout
**Quality notes**: Read actual source again. Found 2 CRITICAL, 3 HIGH severity issues with full exploit chains and file:line references.

## Top Findings
1. **CRITICAL: Pane-text control-plane spoofing** — any [XSM-STATUS] line trusted by signals.py:101, newest wins, flows into landing queue (monitor.py:428)
2. **CRITICAL: Repertoire prompt injection** — raw pane_text injected into classify_blocker prompt (prompt.md:10), returned suggested_action sent back to pane (main.py:1730)
3. **HIGH: Split-brain state persistence** — stale wrangle persists tracker state (main.py:1400) even after epoch rejection at actuation (main.py:1510)
4. **HIGH: Serial subprocess stall** — no timeouts on tmux (tmux.py:999) or evidence (evidence.py:30), serial loop means one hang freezes all
5. **HIGH: Escalation storm, no circuit breaker** — cascade_block_depth parsed but never enforced at runtime

## Unique Findings
- Landing approval bypassed by omission: evaluate_handoff_context exists but leader queueing doesn't call it
- role=="last" check is dead logic — reduces to "any approval marker escalates"
- DB corruption handling fails open: _prepare_db_path DELETES non-SQLite files (state.py:308) = silent amnesia
- Spec changes: routines must return enums only, XSM templates messages itself

## Process Observations
- 167K tokens (down from 347K in phase 1) — more focused with prior context
- Still reads source files to verify claims
- Response was clean, well-structured, followed format
