# Narrowed Proposal: XSM as a Single GitHub Contributor Projection

## Context Shift

The prior council analysis (report.md) assumed OpenClaw patterns would be adopted across the entire Xenota architecture — nucleus, cortex, projections, Gas Town. The council correctly identified risks of creating "second sources of truth" and "split-brain control planes."

**The actual plan is much more contained**: XSM (the swarm manager) would run as a single `github_contributor` projection. It orchestrates multiple coding agents (polecats) working on a single GitHub repo. The nucleus doesn't need to adopt OpenClaw patterns — the projection does.

## What XSM-as-Projection Means

A `github_contributor` projection in Xenota:
- Is containerized (Podman/Docker)
- Has its own workspace under `/var/xenon/data/repos/<owner>/<repo>`
- Communicates with nucleus only through the membrane (validated dispatches)
- Cannot directly mutate nucleus state
- Has projection-scoped storage only
- Can be revoked by the operator

XSM inside this projection would:
- Manage a swarm of coding agents (tmux panes with Claude Code / Codex / Gemini CLI sessions)
- Use deterministic signal-based classification (5 channels, 9 states) to monitor agent health
- Use the wrangle engine to nudge/diagnose/escalate stuck agents
- Coordinate work via beads (issue tracking) assigned to agents
- Use git worktrees for parallel agent work on the same repo

## What Changes from the Prior Analysis

### Scope Containment
- OpenClaw-style patterns (session keys, YAML workflows, factory-line roles, P2P messaging) would operate WITHIN the projection boundary, not at the nucleus/cortex level
- The nucleus doesn't need to change — it just sees "github_contributor projection is active"
- The membrane still validates all inbound dispatches from the projection
- Authority split is preserved: nucleus decides what repo to work on, the projection decides how

### Patterns That Become Safe Within a Projection
1. **Session keys / lightweight addressing**: Agents within the projection can use flat addressing (project:role) because they're all inside the same trust boundary
2. **YAML/deterministic workflows**: The projection can run Lobster-like workflows internally without creating a second workflow engine at the nucleus level
3. **Factory-line role templates**: Programmer/Reviewer/Tester splits make sense for coding agents within one repo
4. **JSONL append-only state**: For tracking agent work within the projection, JSONL is fine — the projection is ephemeral relative to the nucleus
5. **P2P between coding agents**: Agents within the same projection sharing work is expected, not a governance bypass

### Patterns That Remain Risky
1. The projection could still accumulate authority beyond its grant if not capped
2. Token spend within the projection needs budget limits
3. Agent-to-agent coordination within the projection could still create runaway loops
4. The projection's internal state (JSONL) could lose work on crash if not flushed to durable storage

## Questions for the Council

1. How does running XSM inside a single projection change the safety/governance analysis?
2. Which of the prior "killed" proposals should be un-killed for this narrower scope?
3. What new risks appear when you have a swarm-within-a-projection?
4. What's the minimal spec for XSM-as-projection that captures OpenClaw's throughput patterns?
5. How should the projection report its internal swarm state back to the nucleus?
