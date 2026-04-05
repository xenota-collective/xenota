# Phase 2 Summary: Black Hat

## Top Failure Scenarios (consensus across all 3 seats)

1. **Split-brain on crash/restart** — zombie agents, duplicate leases, conflicting PRs (all 3 seats, #1-2 priority). Fix: fencing epochs, live tmux census before SQLite, quarantine-before-respawn.
2. **Prompt injection via repo content into XSM orchestration** — diagnose_idle ingests adversarial content, LLM makes compromised decisions (all 3 seats). Fix: repo content never reaches orchestration as instructions; deterministic gate required after any LLM call.
3. **Merge bomb / landing queue collapse** — 5+ PRs conflict, rebase cascade, churn loop (all 3 seats). Fix: serialized landing queue, one bead in VERIFYING at a time per dependency graph.
4. **Fake forward progress / status spoofing** — agents game activity signals while looping (Codex + Claude). Fix: progress = evidence-bound artifacts (commits passing lint, test state changes), not file touches or terminal output.
5. **Absorption choke / reviewer starvation** — coders outproduce review capacity, queue backs up (all 3 seats). Fix: admission control — no new coders when verify backlog exceeds threshold.
6. **Wrangle feedback cascade** — nudge→retry→fail→nudge loop burns budget (Claude + Gemini). Fix: monotonic wrangle counter per bead, 3 cycles without gate passage → BLOCKED_ESCALATE.
7. **Credential exfiltration via agent-written code** — tests/CI config leak tokens (Claude). Fix: synthetic credentials in test environments, network egress gating, CI/workflow changes require human review.
8. **QA evidence detached from artifact** — review passes commit A, branch rebased to B, bead marked resolved on stale approval (Codex). Fix: QA results content-addressed to exact commit SHA, auto-invalidated on tree change.
9. **Context window amnesia** — agent forgets objective mid-task, hallucinates refactors (Gemini). Fix: inject core objective + diff-so-far into every nudge cycle.
10. **Git index lock / worktree corruption on crash** — agent crashes mid-git-op, lock file blocks next agent (Gemini). Fix: worktrees fully ephemeral — crash = delete worktree, create fresh from latest commit.

## Critical Missing Constraints (consensus)
- Authority map: one fact, one owner (SQLite=leases, beads=task state, git=code, logs=events)
- Fencing epochs on all external actions (stale owners must be harmless)
- Admission control by downstream throughput (not just idle workers)
- Evidence-bound progress (artifacts, not markers)
- Idempotent recovery with compensating actions
- Serialized landing queue
- Hermetic verification (no secrets in agent execution contexts)
