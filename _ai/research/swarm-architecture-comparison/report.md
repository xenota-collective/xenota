# Agent Swarm Architecture Comparison: Deep Comparative Study

**Bead:** xc-ds1y.1.1 · Research alternative agent swarm architectures to Gas Town
**Date:** 2026-03-15
**Author:** xenota/polecats/jasper

---

## Executive Summary

This report compares **10 agent swarm / multi-agent orchestration systems** across 7 architectural dimensions. The systems span from maximally simple (Ralph Loops: a bash while-loop) to maximally structured (Gas Town: Dolt-backed hierarchical orchestration with persistent identity, mail protocol, and managed merge queues).

**The central finding**: the field has bifurcated into two camps that rarely communicate.

1. **Coding agent products** (Devin, Codex, Cursor, Jules, Claude Code) — focus on sandboxing, single-agent execution quality, and git-based landing. Multi-agent is bolted on, hierarchical, shallow (max depth 1), and has no peer coordination.

2. **Multi-agent frameworks** (CrewAI, AutoGen, LangGraph) — focus on coordination patterns, message transport, and agent topology. But they have no opinion on code isolation, repo management, review, or landing.

Gas Town is the only system that seriously addresses *both* — it is simultaneously a coding agent orchestration system (worktrees, merge queue, branch management) and a multi-agent coordination system (beads, mail, escalation, role hierarchy). Ralph Loops occupies a third position: it rejects orchestration entirely and succeeds through radical simplicity.

---

## Systems Compared

| # | System | Category | Origin |
|---|--------|----------|--------|
| 1 | **Gas Town** | Full swarm orchestration | Xenota (internal) |
| 2 | **Ralph Loops** | Anti-orchestration pattern | Geoffrey Huntley (2025) |
| 3 | **Claude Code / Agent SDK** | Coding agent product + SDK | Anthropic |
| 4 | **OpenAI Codex** | Coding agent product | OpenAI |
| 5 | **Devin** | Hosted coding agent | Cognition Labs |
| 6 | **Cursor** | IDE-integrated coding agent | Anysphere |
| 7 | **SWE-agent** | Research benchmark agent | Princeton NLP |
| 8 | **Google Jules** | Hosted coding agent | Google |
| 9 | **CrewAI** | Multi-agent framework | CrewAI Inc |
| 10 | **AutoGen** | Multi-agent framework | Microsoft Research |
| 11 | **LangGraph** | Agent workflow framework | LangChain |

---

## Dimension 1: Worker/Session Model

*How agents are spawned, isolated, and lifecycled.*

### The Spectrum

```
Stateless function ←————————————————————————————→ Persistent identity
  LangGraph nodes    SWE-agent    Ralph    Claude    Codex    Cursor    Devin    Gas Town
                     (run-to-     (loop    (sub-     (cloud   (work-    (cloud   (polecat:
                      completion)  iter)    agent)    task)    tree)     VM)      permanent
                                                                                 identity,
                                                                                 ephemeral
                                                                                 session)
```

### Comparative Table

| System | Session Unit | Lifecycle | State Persistence | Isolation |
|--------|-------------|-----------|-------------------|-----------|
| **Gas Town** | Polecat session (tmux pane) | Identity permanent, session ephemeral, sandbox persistent | Dolt DB + git | Worktrees from mayor/rig |
| **Ralph** | Loop iteration | Fully ephemeral (fresh context each iter) | Files + git only | Single worktree |
| **Claude Code** | Subagent or teammate | Within-session (subagent) or independent (team) | JSONL transcripts, resumable | Git worktrees (optional) |
| **Codex** | Thread (cloud container or local process) | Container cached 12h; local session resumable | Thread event history | Containers (cloud) or OS sandbox (CLI) |
| **Devin** | Cloud VM ("Devin Brain") | Ephemeral per task | Vectorized codebase snapshots + replay timeline | Full VM isolation |
| **Cursor** | Agent tab or background VM | Foreground interactive / background autonomous | IDE state | Worktrees (parallel) or VMs (background) |
| **SWE-agent** | CLI run | Run-to-completion | None beyond patch output | Docker container |
| **Jules** | Cloud VM | Ephemeral per task | None across tasks | Google Cloud VM |
| **CrewAI** | Agent object within Crew | Ephemeral within run; Flow state across runs | 4-tier memory (short/long/entity/contextual) |  None built-in |
| **AutoGen** | ConversableAgent | Runtime-managed; supports distributed | Conversation history | Process/machine boundary |
| **LangGraph** | Node function | Stateless (state is external) | Checkpointed typed state | None built-in |

### Analysis

**Gas Town's separation of identity/sandbox/session is architecturally unique.** No other system distinguishes these three layers. Most systems conflate identity with session (when the session dies, the agent ceases to exist). Gas Town's polecats have permanent CVs, persistent worktrees that survive session death, and ephemeral Claude sessions. This enables capability tracking, A/B testing of models, and work continuity across crashes — none of which any other system supports.

**Ralph's deliberate amnesia is a feature, not a bug.** Each iteration gets a clean context window, preventing the hallucination accumulation and context drift that plague long-running agent sessions. The tradeoff is that complex cross-cutting work cannot span iterations.

**The hosted systems (Devin, Jules, Codex cloud) all converge on VM/container isolation.** This is the simplest correct answer to code isolation but prevents sharing of local state, caches, and tooling configuration across tasks.

---

## Dimension 2: Coordination Model

*How work is distributed and agents coordinate.*

### Topology Comparison

| System | Topology | Concurrent Agents | Decomposition |
|--------|----------|-------------------|---------------|
| **Gas Town** | Hierarchical (Mayor → Witness/Refinery → Polecats) | Many | Beads with parent/child, epics, molecules |
| **Ralph** | None (sequential) | 1 per loop | PRD task list (manual) |
| **Claude Code** | Hierarchical (subagents) + Peer mesh (teams) | Background subagents + team members | Agent tool delegation / shared task list |
| **Codex** | Hierarchical (parent → spawn_agent) | Max 6 threads, depth 1 | CSV batch or manual spawn |
| **Devin** | Independent parallel | N (fleet) | None (each Devin independent) |
| **Cursor** | Independent parallel + subagent trees (2.5) | Up to 8 parallel (worktrees) | Worktree per agent |
| **SWE-agent** | Single agent | 1 | None |
| **Jules** | Independent parallel | Multiple (Ultra tier) | None documented |
| **CrewAI** | Sequential or hierarchical (manager) | ~6 per Crew | Tasks within Crew |
| **AutoGen** | Conversation-based (GroupChat, handoff) | Runtime-managed | Agent selection by GroupChatManager |
| **LangGraph** | Graph (state machine) | Fan-out/fan-in nodes | Graph structure |

### Analysis

**Gas Town is the only system with a true role hierarchy.** Mayor, Witness, Refinery, Polecats — each role has distinct responsibilities, lifecycle, and supervision relationships. Every other system either has flat topology (Devin, Jules, Ralph) or shallow hierarchy (Claude Code subagents, Codex spawn, Cursor subagents — all max depth 1).

**The "fleet of independent agents" pattern is dominant** in coding agent products. Devin, Jules, Cursor parallel agents, and Codex cloud tasks all use the same model: N independent agents, each on their own task, no coordination between them. This works for embarrassingly parallel work (N independent bug fixes) but fails for coordinated feature development.

**CrewAI's manager agent pattern is elegant but fragile** — it depends entirely on the manager LLM's ability to decompose and delegate correctly. AutoGen's GroupChat has the same weakness: LLM-based speaker selection is non-deterministic.

**LangGraph's graph-based coordination is the most precise** but requires explicit design. You get exactly the coordination you wire up, nothing more. This makes it powerful for known workflows but brittle for emergent coordination needs.

**Gas Town's molecule system bridges declarative and emergent coordination.** Formulas define workflow structure; agents execute autonomously within steps. This is more structured than "N independent agents" but less rigid than LangGraph's explicit graph.

---

## Dimension 3: Message Transport

*How agents communicate with each other.*

### Transport Mechanism Comparison

| System | Primary Transport | Persistence | Bidirectional | Cross-Agent |
|--------|------------------|-------------|---------------|-------------|
| **Gas Town** | Dolt-backed beads + mail + nudge | Durable (beads/mail) or ephemeral (nudge) | Yes | Yes (any agent → any agent) |
| **Ralph** | Filesystem | File durability | No (write-only per iteration) | No |
| **Claude Code** | Agent tool return (subagents) / Mailbox (teams) | Session-scoped | One-way (subagents) / Yes (teams) | Subagents: no / Teams: yes |
| **Codex** | Instruction-at-spawn + result-at-completion | Thread-scoped | No | No peer-to-peer |
| **Devin** | REST API + Slack + GitHub | External platforms | Via human intermediary | No |
| **Cursor** | IDE UI | Session-scoped | Via human | No |
| **SWE-agent** | None | None | No | N/A |
| **Jules** | GitHub issues/PRs | GitHub persistence | Via human | No |
| **CrewAI** | Task output chaining / manager mediation | Within-run | Indirect | Within Crew only |
| **AutoGen** | Typed async messages via runtime | Conversation-scoped | Yes | Yes (distributed) |
| **LangGraph** | Shared state mutation | Checkpointed | Via state | Via state object |

### Analysis

**Gas Town's three-tier communication (beads/mail/nudge) is the most architecturally sophisticated messaging system in this comparison.** The separation of durable (beads), persistent (mail), and ephemeral (nudge) communication channels with explicit cost/durability tradeoffs is a design pattern no other system implements. The "default to nudge" rule is an elegant solution to the message accumulation problem.

**AutoGen has the strongest *generic* message transport** — truly async, typed, distributable across processes and machines. But it has no opinion on message durability, communication cost, or hygiene. Every message is the same weight.

**Most coding agent products have no inter-agent communication at all.** Devin, Cursor, Jules, and SWE-agent rely on humans or external platforms (GitHub, Slack) as the communication bridge between agent sessions. This means coordination latency is measured in minutes or hours (human review cycle), not seconds.

**Claude Code's agent teams mailbox is a lightweight peer messaging system** but lacks Gas Town's durability guarantees and cost-awareness. All messages have equal weight; there's no nudge-vs-mail distinction.

---

## Dimension 4: Escalation Model

*How blockers and errors flow upward.*

### Escalation Comparison

| System | Formal Protocol | Severity Levels | Routing | Auto-Escalation |
|--------|----------------|-----------------|---------|-----------------|
| **Gas Town** | Yes (gt escalate) | CRITICAL/HIGH/MEDIUM | Agent → Deacon → Mayor → Overseer | Stale threshold (4h default) |
| **Ralph** | No | N/A | Restart loop | N/A |
| **Claude Code** | No (hook-based) | N/A | Permission prompts → user | Hook exit code 2 blocks |
| **Codex** | No (approval-based) | N/A | Sandbox boundary → approval request | Auto-rejection policies |
| **Devin** | No | N/A | Chat question to human | None |
| **Cursor** | No | N/A | Sandbox elevation request | YOLO mode bypasses |
| **SWE-agent** | No | N/A | None (run to completion) | None |
| **Jules** | No | N/A | Plan approval request | None |
| **CrewAI** | No | N/A | Manager reassignment (hierarchical) | Retry with timeout |
| **AutoGen** | No | N/A | Handoff to UserProxyAgent | Termination conditions |
| **LangGraph** | No | N/A | interrupt() pauses graph | Checkpoint resume |

### Analysis

**Gas Town is the only system with a formal, structured escalation protocol.** Severity levels, routing chains, stale detection with auto-re-escalation, and multi-tier resolution (Deacon → Mayor → Overseer) are unique to Gas Town. This is a genuinely novel architectural contribution.

**Every other system either restarts (Ralph), asks the human (Claude Code, Codex, Devin, Cursor, Jules), or has no escalation at all (SWE-agent).** The "ask the human" pattern works for interactive use but breaks down for autonomous/overnight execution. If the agent hits a blocker at 3 AM, it just stops.

**LangGraph's interrupt() is the most elegant *technical* escalation mechanism** — it pauses the graph, preserves state, and allows the human to edit state before resuming. But it's a mechanism, not a protocol. There's no severity, no routing, no auto-escalation.

**Claude Code's hook system provides escalation *infrastructure*** — you can build escalation protocols with hooks (PreToolUse → deny → user prompt chain). But it's build-your-own, not batteries-included.

---

## Dimension 5: Repo/Worktree Model

*How code changes are isolated per agent.*

### Isolation Comparison

| System | Mechanism | Concurrent Isolation | Conflict Resolution |
|--------|-----------|---------------------|---------------------|
| **Gas Town** | Worktrees from mayor/rig (persistent) | Yes (each polecat has own worktree) | Refinery merge queue (batch-then-bisect) |
| **Ralph** | Single worktree | No (sequential) | Manual |
| **Claude Code** | Git worktrees (auto-created, auto-cleaned) | Yes (isolation: worktree per subagent) | Manual merge or worktree "Apply" |
| **Codex** | Container clone (cloud) / local dir (CLI) | Yes (per container) | Manual (PR-based) |
| **Devin** | VM clone | Yes (per VM) | Manual (PR-based) |
| **Cursor** | Git worktrees (up to 20) | Yes (up to 8 parallel) | Native conflict resolution UI |
| **SWE-agent** | Docker container clone | Yes (per container) | N/A (patches only) |
| **Jules** | VM clone | Yes (per VM) | Manual (PR-based) |
| **CrewAI** | None | N/A | N/A |
| **AutoGen** | None | N/A | N/A |
| **LangGraph** | None | N/A | N/A |

### Analysis

**Git worktrees have emerged as the consensus isolation mechanism** for local coding agents (Gas Town, Claude Code, Cursor). Container/VM cloning is the cloud equivalent (Codex, Devin, Jules, SWE-agent). The multi-agent frameworks (CrewAI, AutoGen, LangGraph) have no opinion on code isolation.

**Gas Town's persistent worktrees are unique.** Claude Code and Cursor create and destroy worktrees per-task. Gas Town worktrees persist across assignments — a polecat's worktree survives session death and is reused on the next sling. This eliminates setup overhead for subsequent assignments to the same polecat.

**Gas Town's Refinery merge queue is the only automated merge/conflict resolution system.** Batch-then-bisect (Bors-style) is a production-grade approach to merge contention. Every other system either punts to the human (PR review) or has no merge story at all.

---

## Dimension 6: Review/Landing

*How agent work gets validated and merged.*

### Review/Landing Comparison

| System | Review Mechanism | Landing Mechanism | Autonomous Merge |
|--------|-----------------|-------------------|------------------|
| **Gas Town** | Witness monitoring + Refinery gates | Merge queue (batch-then-bisect) | Yes (Refinery) |
| **Ralph** | Quality gates (tests/typecheck) only | Manual merge | No |
| **Claude Code** | Hook-based gates; plan approval (teams) | gh pr create → human merge | No |
| **Codex** | @codex review (GitHub integration) | PR → human merge | No |
| **Devin** | Devin Review (structured code review) | PR → human merge | No |
| **Cursor** | Human review in IDE | "Apply" button or PR | No |
| **SWE-agent** | None (produces patches) | Manual application | No |
| **Jules** | Plan review before execution | PR → human merge | No |
| **CrewAI** | Guardrails validation | N/A | N/A |
| **AutoGen** | Code execution sandbox | N/A | N/A |
| **LangGraph** | Checkpoint-based state validation | N/A | N/A |

### Analysis

**Gas Town is the only system that can autonomously merge code.** The Refinery runs quality gates, batches MRs, tests the batch, and fast-forward merges on success. Every other coding agent system requires human approval for merge. This is a significant capability gap — without autonomous merge, agent throughput is gated by human review bandwidth.

**The universal landing surface is the GitHub PR.** Codex, Devin, Cursor (background), Jules, and Claude Code all produce PRs. Gas Town's Refinery can target either integration branches or main directly, with configurable conflict handling.

**Ralph's "quality gates are the review" philosophy is surprisingly effective** for well-specified work. If your test suite is comprehensive, passing tests IS the review. This breaks down for work that requires judgment beyond test coverage.

---

## Dimension 7: Operator Control

*How the human operator maintains oversight and steering.*

### Control Surface Comparison

| System | Configuration | Runtime Steering | Permission Model | Enterprise |
|--------|--------------|------------------|------------------|------------|
| **Gas Town** | CLAUDE.md, town.json, daemon.json, formulas | gt sling/nudge/escalate/convoy | Role-based (BD_ACTOR) | N/A (self-hosted) |
| **Ralph** | PROMPT.md, iteration limits, quality gates | CTRL+C pause, prompt editing | None (operator trust) | N/A |
| **Claude Code** | CLAUDE.md, settings.json, hooks, agents/ | Permission prompts, /tasks, Ctrl+B/F | 5-tier hierarchy, managed settings, OS sandbox | Managed settings, sandbox restrictions |
| **Codex** | AGENTS.md, codex.toml, agent configs | Approval flow, sandbox modes | 3 sandbox modes + approval policies | Admin policies, OpenTelemetry |
| **Devin** | Playbooks + Knowledge | Chat steering, plan modification | Secrets management, VPC deployment | VPC, SSO, audit |
| **Cursor** | .cursorrules, worktrees.json | IDE interaction, YOLO mode | Sandbox (Seatbelt/Landlock) | N/A |
| **SWE-agent** | YAML config | None (batch mode) | Container isolation | N/A |
| **Jules** | Plan review | Plan modification mid-execution | VM isolation | Google Cloud |
| **CrewAI** | YAML crew definitions, Flow decorators | Flow @listen for human input | None built-in | AMP Suite (paid) |
| **AutoGen** | Code configuration | human_input_mode on UserProxyAgent | Runtime boundaries | Microsoft Agent Framework |
| **LangGraph** | Graph definition, state schema | interrupt() + state editing + time travel | None built-in | LangGraph Platform |

### Analysis

**Claude Code has the most sophisticated permission model** — 5-tier hierarchy with deny-wins semantics, managed settings for enterprise lockdown, OS-level sandboxing as defense-in-depth, and 12+ hook points for lifecycle interception. This is the gold standard for operator control in coding agents.

**Gas Town has the most sophisticated *operational* control** — convoy tracking, role-based assignment, structured escalation, daemon monitoring, and molecule-based workflow orchestration. But it lacks Claude Code's permission granularity and sandbox enforcement.

**LangGraph has the best *debugging* control** — checkpoint-based time travel lets operators fork from any historical state, edit state directly, and resume. No other system offers this.

**Ralph has the simplest and most honest control model** — the operator controls the prompt and the iteration limit. Everything else is the agent's problem. This forces good specification discipline.

---

## Cross-Cutting Observations

### What's Elegant

1. **Gas Town's identity/sandbox/session separation** — solves the "disposable agent" problem that every other system has. When a Claude session crashes, the polecat identity and worktree survive. Work can resume without setup overhead.

2. **Ralph's deliberate simplicity** — rejecting orchestration infrastructure in favor of a bash loop is a genuine architectural insight. Most orchestration overhead exists to solve coordination problems that disappear when you serialize execution.

3. **LangGraph's checkpoint + time travel** — the ability to fork from any historical state is a debugging superpower that no other system matches.

4. **Claude Code's hook system** — 12+ lifecycle interception points with allow/deny/ask semantics make the system infinitely composable without being infinitely complex.

5. **Gas Town's nudge/mail/bead communication tiers** — explicitly modeling communication cost prevents the message accumulation that kills long-running multi-agent systems.

### What's Fragile

1. **Gas Town's Dolt dependency** — single server, no embedded mode, fragile under load. The entire coordination layer depends on one process staying healthy.

2. **CrewAI/AutoGen's LLM-based coordination** — manager agents and GroupChat speaker selection depend on LLM judgment, which is non-deterministic and degrades under load.

3. **Codex's approval flow** — known bugs where UI loses sync with backend, leaving tasks permanently blocked with no automatic recovery.

4. **Devin's proprietary model dependency** — the entire system depends on Cognition's proprietary SWE models. No fallback to open models.

### What's Overbuilt

1. **AutoGen's distributed runtime** — cross-machine, cross-organization agent messaging is architecturally impressive but most users run everything in one process. The 0.2→0.4 rewrite added distributed capabilities that the ecosystem hasn't caught up with.

2. **Gas Town's molecule system** (for simple tasks) — the formula/protomolecule/pour/root-only distinction adds complexity. For simple sling-and-work flows, this is overhead. The root-only default mitigates this.

3. **LangGraph's state reducer system** — powerful for concurrent state management but steep learning curve for workflows that are fundamentally sequential.

### What's Underbuilt

1. **Escalation in every system except Gas Town** — this is the most glaring gap across the entire landscape. Agents get stuck, and the only recovery is "ask the human" or "restart." For autonomous/overnight operation, this is a showstopper.

2. **Inter-agent communication in coding agent products** — Devin, Codex, Cursor, and Jules have no way for agents to talk to each other. They're parallel but isolated.

3. **Review/landing automation** — only Gas Town has autonomous merge capability. Every other system requires human approval for every PR. At scale, this bottleneck dominates.

4. **Agent identity and capability tracking** — only Gas Town tracks who-did-what with permanent attribution. Every other system treats agents as anonymous executors.

---

## Implications for Gas Town Light / ZSM

### What Gas Town Should Keep

1. **Persistent identity with CV tracking** — unique capability; no competitor offers this. Essential for capability-based routing and quality measurement.

2. **Structured escalation** — the only system that solves overnight autonomy. Keep severity levels, routing chains, and stale detection.

3. **Communication cost tiers** — nudge/mail/bead separation prevents message accumulation. Every multi-agent system that doesn't model communication cost eventually drowns in its own messages.

4. **Merge queue (Refinery)** — the only automated landing system. This is a genuine competitive advantage for throughput.

### What Gas Town Should Learn From Others

1. **From Ralph: simplicity as a feature.** The bash loop works because it eliminates entire categories of bugs (state corruption, coordination deadlocks, message loss). Gas Town Light should ask: for a solo developer with 3 polecats, how much orchestration is actually needed? The answer might be closer to Ralph than to full Gas Town.

2. **From Claude Code: hook-based extensibility.** Rather than building every quality gate into the system, expose lifecycle hooks and let operators compose their own gates. This is more maintainable than a growing list of built-in gates.

3. **From LangGraph: checkpoint and time travel.** Being able to inspect and replay agent decision points would dramatically improve debugging. Gas Town's Dolt versioning provides the *data* history but not the *agent decision* history.

4. **From Codex: wire protocol design.** The App Server's Item/Turn/Thread model is a clean abstraction for agent interaction that decouples client surfaces from execution. If Gas Town Light needs a client API, this is a good model.

5. **From Cursor: native worktree UX.** Cursor's worktree sync (copying new/edited files to worktrees at launch) and conflict resolution UI are polish that improves the developer experience of parallel agent work.

### Where the Market Is Heading

1. **Convergence on git worktrees + PRs** as the universal code isolation and landing surface.
2. **"Fleet of independent agents"** as the default multi-agent pattern (not coordinated swarms).
3. **No one else is building escalation or autonomous merge.** These are genuine differentiators.
4. **Hooks and extensibility** over built-in features. Claude Code and Codex both trend toward "give operators hooks and let them compose."
5. **Context window refresh** (Ralph pattern) gaining adoption as an alternative to long-running sessions.

### Concrete Recommendations

1. **Gas Town Light should offer a "Ralph mode"** — a minimal loop that reads a task list, executes one task per fresh session, commits, and loops. This covers the 80% case (solo dev, serial execution) without any orchestration infrastructure.

2. **Preserve escalation and merge queue as opt-in capabilities** that layer on top of Ralph mode when the operator needs them.

3. **Adopt hook-based extensibility** from Claude Code for quality gates rather than building gates into the system.

4. **Consider dropping Dolt for simple cases** in favor of filesystem + git (Ralph-style state). Dolt adds genuine value for multi-agent coordination, attribution, and audit — but for 1-3 agents, the overhead may not justify the fragility.

5. **Add agent decision logging** (inspired by LangGraph checkpoints) to enable debugging agent behavior after the fact.

---

## Source Summary

### Per-System Sources

All research artifacts with full source lists are at `_ai/research/`:

| System(s) | Artifact Directory | Source Count |
|-----------|-------------------|--------------|
| Ralph Loops | `ralph-loops/` | 10 sources |
| Claude Agent SDK | `claude-agent-sdk-architecture/` | 10 sources |
| OpenAI Codex | `openai-codex-architecture/` | 19 sources |
| CrewAI, AutoGen, LangGraph | `multi-agent-framework-comparison/` | 10 sources |
| Devin, SWE-agent, Cursor, Jules | `coding-agent-architectures/` | 15+ sources |
| Gas Town | Local codebase exploration | ~20 design docs |

### Key Primary Sources

- Geoffrey Huntley, "ralph wiggum as a software engineer" (ghuntley.com/ralph/) — Ralph Loops origin
- Geoffrey Huntley, "everything is a ralph loop" (ghuntley.com/loop/) — Ralph philosophy
- Claude Code docs (code.claude.com/docs/) — Subagents, teams, hooks, permissions
- OpenAI, "Unrolling the Codex Agent Loop" — App Server architecture
- Codex docs (developers.openai.com/codex/) — Multi-agent, sandboxing, config
- Devin docs (docs.devin.ai/) — Playbooks, Review, VPC
- SWE-agent docs (swe-agent.com/) — Architecture, SWE-ReX runtime
- Cursor docs (cursor.com/docs/) — Worktrees, agent configuration
- Gas Town design docs — architecture.md, dolt-storage.md, escalation.md, polecat-lifecycle.md, identity.md, molecules.md, propulsion-principle.md
