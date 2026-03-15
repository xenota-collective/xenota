# Research Summary: Ralph Loops

## Objective

Investigate "Ralph Loops" as an agent orchestration architecture for comparative study against Gas Town.

## Top Findings

1. **Ralph Loops is real and well-documented.** Created by Geoffrey Huntley (June 2025), it is a widely adopted technique for autonomous AI coding. The name references Ralph Wiggum from The Simpsons. Anthropic shipped an official Claude Code plugin for it in December 2025.

2. **The architecture is deliberately minimal.** The entire system is a bash loop (`while :; do cat PROMPT.md | claude-code ; done`) that repeatedly spawns fresh agent instances. State persists through the filesystem and git, not through any coordination service. There is no message transport, no supervisor hierarchy, no inter-agent communication.

3. **It occupies the opposite end of the design spectrum from Gas Town.** Gas Town provides hierarchical coordination, role-based agents, Dolt-backed state, structured escalation, and managed landing. Ralph provides none of these. The comparison is maximally instructive -- it tests whether orchestration complexity pays for itself.

4. **Ralph's strengths are Gas Town's weaknesses and vice versa.** Ralph excels at simplicity, debuggability, zero setup cost, and context hygiene. It fails at parallel coordination, cross-cutting changes, escalation, and shared learning. Gas Town addresses all of Ralph's coordination gaps but at substantial complexity and infrastructure cost.

5. **Community extensions bridge the gap partially.** Projects like ralph-orchestrator add role-based hats, event-driven coordination, and human-in-the-loop via Telegram. These extensions move toward Gas Town's territory but remain lighter-weight.

6. **A direct comparison already exists in public discourse.** Chris Parsons argued that Gas Town is "just a series of Ralph loops with extra steps." This framing, while reductive, identifies the core question: when does orchestration overhead justify itself?

## Recommendations

- The comparative study should focus on the coordination gap: what capabilities does Gas Town's infrastructure (beads, Dolt, roles, escalation) enable that Ralph fundamentally cannot do?
- Examine the cost/complexity tradeoff: Ralph at $0 infrastructure vs Gas Town's Dolt server, agent roles, and mail protocol.
- Consider the "middle ground" that multiple commentators identify: a lightweight coordinator that can delegate to Ralph-style loops without Gas Town's full infrastructure.
- Test both systems against the same task types: (a) single-file feature work (Ralph's sweet spot), (b) cross-cutting refactors requiring coordination (Gas Town's sweet spot), (c) ambiguous discovery tasks (neither system's sweet spot).

## Confidence Level

**HIGH.** Ralph Loops is extensively documented across primary sources (creator's blog), canonical implementations (GitHub repos), industry commentary, and official vendor support (Anthropic plugin). The architecture is simple enough to be fully understood from available sources.

## Open Questions

- How does Ralph's "overbaking" failure mode compare to Gas Town's agent drift patterns?
- What is the actual token/cost comparison for equivalent tasks?
- Has anyone run both systems on the same project and published results?
- How does ralph-orchestrator's hat system compare to Gas Town's role system in practice?
