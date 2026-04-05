# Phase 3 Summary: Simplify

## Strong consensus across all 3 seats on core principles:

1. XSM is the only coordinator; agents never self-route or coordinate directly
2. Swarm proposes, humans decide — no auto-merge, human merge gate is absolute
3. Repo content is adversarial input — never reaches orchestration as instructions
4. One fact, one authority — explicit authority map (SQLite=leases, beads=task state, git=code, GitHub=merges)
5. One bead ↔ one agent ↔ one worktree — enforced by SQLite unique constraints
6. Fencing epochs on all external actions — stale agents become harmless
7. Progress is evidence-bound — commits passing lint, test state changes, not file touches or terminal output
8. Serialized landing queue — one bead in VERIFYING at a time per dependency graph
9. QA approval content-addressed to exact commit SHA — auto-invalidated on tree change
10. Admission gated by downstream absorption capacity — no new coders when verify backlog exceeds threshold
11. Worktrees fully ephemeral — crash = delete and recreate, never repair
12. 3 wrangle cycles without evidence → BLOCKED_ESCALATE (structural, not advisory)
13. Budget exhaustion stops work, never relaxes gates
14. Recovery: census first, reconcile second, quarantine mismatches, idempotent
15. CI/workflow/dependency changes require mandatory human review

## Key v1 scope cuts (Claude):
- Cut: repertoire bridge / diagnose_idle in orchestration (injection vector)
- Cut: cross-model adversarial review (complex, defer to required human reviewer)
- Cut: 9 states → 6 states (merge idle_prompt+stalled→IDLE, crashed+orphaned→ZOMBIE)
- Cut: LLM processing of leader inbox content

## Work lifecycle: ASSIGNED → ISOLATED → ACTIVE → REVIEWING → VERIFYING → RESOLVED (with BLOCKED_ESCALATE and FAILED exits)
## Agent lifecycle: SPAWN → MONITOR → WRANGLE → TERMINATE (with QUARANTINE for split-brain)
## 5 kill conditions: budget exhaustion, split-brain, prompt injection quarantine, merge bomb, no forward progress within TTL
