# Coding Agent Architectures: Comparative Summary

## Objective
Compare the architecture of four coding-specific agent systems -- Devin, SWE-agent, Cursor Agent Mode, and Google Jules -- across session model, coordination, code isolation, review, operator control, and multi-agent support.

## Confidence Level
**Medium-High.** Devin and SWE-agent have the most public architectural detail (docs + open source respectively). Cursor has good documentation on worktrees/sandboxing but less on internals. Jules has the least architectural transparency -- mostly marketing-level descriptions.

---

## Comparative Matrix

| Dimension | Devin | SWE-agent | Cursor | Jules |
|-----------|-------|-----------|--------|-------|
| **Type** | Hosted async agent | Open-source CLI tool | IDE with embedded agent | Hosted async agent |
| **Execution env** | Cloud VM per session | Docker container (or Fargate/Modal) | Local IDE + cloud VMs (background) | Ephemeral GCP VM per task |
| **Model** | Proprietary (SWE-1.5, SWE-grep) | Any LLM (GPT-4, Claude, etc.) | Proprietary + third-party | Gemini 2.5 Pro / 3 Pro |
| **Session lifecycle** | Long-lived, stateful (memory layer) | Ephemeral, run-to-completion | Interactive or background | Ephemeral per task |
| **Sandboxing** | VM isolation, VPC deployment option | Docker + optional gVisor | OS-level (Seatbelt/Landlock) | GCP VM isolation |
| **Code isolation** | Branch per session | Clone in container | Git worktrees (up to 20) | Clone in ephemeral VM |
| **Parallelism** | Multiple independent sessions | Parallel benchmark runs via SWE-ReX | Up to 8 parallel agents | Parallel tasks in separate VMs |
| **Multi-agent coord** | None (independent fleet) | None | Subagent trees (v2.5) | Hinted at Ultra tier |
| **Review/landing** | PR on GitHub, human review | Produces patch only | Apply/merge in IDE or PR | PR on GitHub, human review |
| **Operator control** | Playbooks, Knowledge, API, VPC | YAML config, custom tools | .cursorrules, YOLO mode, automations | Plan review, CLI |
| **Escalation** | Chat-based human questions | None (runs to completion) | Sandbox permission requests | Plan approval, mid-exec modification |
| **Swarm support** | No | No | Partial (subagent trees) | Unclear |

---

## Top Findings

### 1. All systems use VM or container isolation, none share a working directory across agents
Every system isolates agent execution at the process/container/VM boundary. Code changes are never made to a shared worktree by multiple agents simultaneously. The isolation boundary varies:
- Devin/Jules: full cloud VMs
- SWE-agent: Docker containers
- Cursor: OS-level sandbox + git worktrees for local, VMs for background agents

### 2. True multi-agent coordination is absent or nascent
No system has a documented inter-agent coordination protocol. The closest is Cursor 2.5's subagent spawning, which creates tree-structured task decomposition, but there is no peer-to-peer agent communication or shared state. Devin's "fleet" is N independent agents. Jules Ultra tier hints at multi-agent but details are not public.

### 3. Git is the universal integration surface
All four systems use git branches/PRs as the mechanism for landing changes. None bypass the standard GitHub PR flow for production use. This means the review/landing model is fundamentally the same: agent creates branch, opens PR, human reviews and merges.

### 4. Operator control sophistication varies significantly
- Devin has the richest operator model: Playbooks (procedural), Knowledge (declarative), Secrets, API, VPC deployment.
- Cursor has .cursorrules, automations, and sandbox configuration.
- SWE-agent has YAML config and custom tool definitions but no runtime operator intervention.
- Jules has the least documented control surface.

### 5. Escalation is uniformly weak
No system has a formal, structured escalation framework with severity levels, routing, or fallback chains. At best, agents pause and ask the human (Devin, Cursor, Jules). SWE-agent has no escalation at all. This is a significant gap compared to what a production multi-agent system would need.

### 6. The hosted-vs-local divide maps to async-vs-interactive
- Devin and Jules are hosted, asynchronous, and fire-and-forget. The human reviews output after completion.
- Cursor is primarily interactive (foreground agents) with a growing async capability (background agents).
- SWE-agent is CLI-driven and batch-oriented.

---

## Recommendations

1. **For designing a multi-agent coding system**, none of these provide a reusable coordination protocol. Cursor's subagent trees are the most interesting direction, but the coordination is hierarchical (parent spawns children), not peer-to-peer.

2. **For operator control patterns**, Devin's Playbook/Knowledge split (procedural vs. declarative context) is a well-designed pattern worth studying.

3. **For sandboxing**, the diversity of approaches (VM, Docker, OS sandbox, worktrees) suggests there is no consensus on the right abstraction level. The trend is toward heavier isolation (VMs) for background/async agents.

4. **The escalation gap is real.** Any production multi-agent system needs to solve: how does an agent signal it is blocked? Who receives the signal? What is the fallback? None of these systems have satisfying answers.

---

## Open Questions

- How does Cursor 2.5's subagent tree actually coordinate? Is there shared memory, or just return values?
- What does Jules Ultra tier's "multi-agent support" actually entail?
- Does Devin's memory layer enable cross-session learning, or is it session-scoped?
- How do any of these systems handle conflicting changes when multiple agents touch overlapping files?

---

## Sources
See [sources.md](sources.md) for full source index with URLs and authority ratings.
See [details.md](details.md) for per-system deep dives.
