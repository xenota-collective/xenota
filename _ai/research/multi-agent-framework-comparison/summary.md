# Multi-Agent Framework Comparison: Summary

## Objective
Comparative architecture study of CrewAI, Microsoft AutoGen, and LangGraph -- the three major open-source multi-agent orchestration frameworks. Focus on architectural patterns and design decisions, not API usage.

## Top Findings

### Each framework embodies a different core metaphor

- **CrewAI** = a team of employees. Agents have roles, goals, and backstories. Work is organized as Tasks delegated within Crews. A separate Flows layer handles structured workflow control.
- **AutoGen** = a conversation. Agents exchange async messages through a runtime. The framework's strongest feature is its distributed message transport -- agents can run across processes, machines, and organizational boundaries.
- **LangGraph** = a state machine. Workflows are directed graphs where nodes (functions) transform shared typed state. Edges route execution conditionally. No first-class "agent" abstraction exists.

### The frameworks make fundamentally different coordination tradeoffs

| | CrewAI | AutoGen | LangGraph |
|---|---|---|---|
| Coordination | Task delegation (sequential or via manager) | Message passing (async, distributed) | State mutation (shared typed dict) |
| Agent identity | Strong (role, goal, backstory) | Medium (system message, capabilities) | None (nodes are anonymous functions) |
| Human control | Flow-step level | Per-turn via UserProxyAgent | Per-node interrupts + state editing + time travel |
| Distribution | Single process | Native cross-process/cross-machine | Single process (Platform for distributed) |
| Error recovery | Retry + manager reassignment | Conversation retry + human handoff | Checkpoint-based resume with partial preservation |
| Learning curve | Low | Medium | High |

### Key architectural insight: message transport is the decisive differentiator

- **CrewAI** has no message bus. Agents communicate indirectly through task output chaining or manager mediation. This is simple but limits flexibility.
- **AutoGen** has true async message passing with typed messages, pub/sub topics, and distributed routing. This is the most sophisticated transport but adds complexity.
- **LangGraph** has no messages at all. All communication is shared state mutation with reducer functions handling concurrent writes. This gives maximum control but couples all nodes to the state schema.

### Human-in-the-loop: LangGraph leads decisively

LangGraph's interrupt/checkpoint/time-travel model is architecturally superior for human oversight. The ability to pause at any node, edit state, fork from historical checkpoints, and resume is unmatched. CrewAI and AutoGen handle human input but cannot match LangGraph's granularity or state manipulation capabilities.

## Recommendations

1. **For role-based task decomposition with moderate complexity**: CrewAI. The role metaphor maps naturally to business processes. The Flows+Crews architecture handles the common case of "some parts need structure, some parts need autonomy."

2. **For distributed systems or conversation-heavy workloads**: AutoGen. The async message transport and distributed runtime are genuine differentiators. However, monitor the AutoGen-to-Microsoft-Agent-Framework transition carefully.

3. **For workflows requiring precise control, human oversight, or fault tolerance**: LangGraph. The state machine model, checkpointing, and interrupt system are best-in-class for safety-critical or complex branching workflows.

4. **None of these frameworks solve code isolation** (repo/worktree model) or formal review/landing workflows. These are application-level concerns that must be built on top.

## Confidence Level
**High** for architectural descriptions and comparisons. Based on primary documentation, official blogs, and GitHub repos. All three frameworks are evolving rapidly (AutoGen especially), so specific API details may shift.

## Open Questions
- How does Microsoft Agent Framework (AutoGen successor, GA target Q1 2026) change the landscape?
- Will A2A and MCP protocol adoption converge the frameworks toward interoperability?
- How do these frameworks perform under real production load at scale (100+ agents)?
- What is the actual token/cost overhead of each framework's coordination patterns?

## Time Sensitivity
High. AutoGen's transition to Microsoft Agent Framework is ongoing. CrewAI's Flows abstraction is relatively new. All frameworks are pre-1.0 in effective maturity. Recommend review by Q3 2026.
