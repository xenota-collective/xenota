# Phase 1 Summary: Ideation

## Codex (Systems Critic)
- Strongest element: deterministic coordination first, model intelligence second
- Will fail first: ownership ambiguity — unresolved authority split between SQLite, beads, git, tmux
- Must-have principles: (1) every fact has one authority, (2) exclusive fenced ownership with leases, (3) progress requires evidence not markers, (4) admission constrained by absorption capacity, (5) recovery must be idempotent
- Missing: authority map, lease/heartbeat model, admission control, merge/landing model, forward progress definition, handoff artifacts, replay-safe vs dedupe actions, prompt injection hardening

## Claude (Safety Auditor)
- Core principle: "The swarm produces proposals. Humans produce decisions."
- Must-have: human authority over merges is absolute, repo content is adversarial, attribution is immutable, scope enforced structurally not behaviorally, budget exhaustion stops work never relaxes gates
- Top abuse paths: prompt injection via repo content, merge bomb via parallel conflicts, supply chain injection via dependencies, status spoofing to game XSM classification, credential exfiltration via agent-written code
- QA model: 5 layers (structural gates, adversarial cross-model review, integration verification, human review thresholds, rollback capability)
- Approval laundering prevention: PR rate limiting, no auto-merge for swarm PRs, reviewer rotation, complexity-gated cooling periods

## Gemini (Pragmatist)
- Simplest work lifecycle: ASSIGNED → ISOLATED → ACTIVE → VERIFYING → RESOLVED/FAILED
- Simplest agent lifecycle: SPAWN → MONITOR → WRANGLE → TERMINATE
- Budget model: wall-clock TTL per bead, action budget (max N nudges), financial cap at projection boundary
- Recovery: read SQLite → scan infrastructure → resolve dissonance → resume
- Top 10 principles drafted: infrastructure is authority, one worktree per bead, flat identifiers, append-only state, factory-line decomposition, deterministic intervention, aggressive pruning, untrusted outputs, no direct inter-agent messaging, stateless resumption in <5s
