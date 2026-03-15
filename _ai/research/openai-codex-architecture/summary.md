# OpenAI Codex Agent Architecture: Summary

## Objective
Architectural analysis of OpenAI Codex's agent execution model for comparative study of multi-agent orchestration systems.

## Top Findings

**1. Unified App Server Architecture.** Codex uses a single bidirectional protocol (JSON-RPC over JSONL/stdio locally, HTTP/SSE for web) built on three primitives -- Item, Turn, Thread -- that powers every surface: CLI, VS Code, web app, desktop, and third-party IDEs. The Rust-based `codex-rs` workspace (65+ crates) is now the maintained implementation.

**2. Two execution environments, same protocol.** Cloud Codex runs each task in an isolated container (repo cloned, internet disabled during execution, container cached up to 12h). CLI Codex runs locally with OS-native sandboxing (macOS Seatbelt, Linux Landlock/Bubblewrap). Both share the App Server wire protocol.

**3. Multi-agent is experimental and hierarchical.** Codex supports spawning sub-agents via `spawn_agent` and `spawn_agents_on_csv`. Communication is strictly parent-to-child (instruction at spawn, result at completion). No peer-to-peer messaging, no shared state, no swarm patterns. Max 6 concurrent threads, max depth 1 by default.

**4. Not a general-purpose orchestration framework.** Unlike CrewAI, AutoGen, or LangGraph, Codex is a coding agent product with multi-agent as an add-on. It lacks pluggable agent types, message bus architecture, or graph-based workflow definitions. Its strength is deep execution isolation and long-running autonomous coding (7+ hours with GPT-5.3-Codex).

**5. Codex as MCP server enables external orchestration.** Running `codex mcp-server` exposes Codex sessions as tools callable from the OpenAI Agents SDK, allowing external Project Manager agents to coordinate multiple Codex instances. This is the closest to a "swarm" pattern -- but orchestration lives outside Codex.

**6. Escalation is approval-based, not protocol-based.** When the agent hits sandbox boundaries, it pauses and requests approval. There is no structured error recovery protocol; the model reasons about errors. Known issues include stuck approvals, missing escalation requests, and subagent hangs with no timeout.

## Recommendations

- For comparative analysis: Codex should be categorized as a **product agent with limited multi-agent extensions**, not as a multi-agent framework. Its architectural contributions are in sandboxing, wire protocol design, and long-running execution -- not in coordination patterns.
- The MCP server integration pattern is worth studying as a bridge between product agents and external orchestration frameworks.
- The App Server's Item/Turn/Thread primitive model is a clean abstraction that could inform protocol design for other agent systems.

## Confidence Level
**High** for architecture, sandboxing, and execution model (based on primary docs and open source code). **Medium** for multi-agent specifics (feature is experimental, docs are sparse). **Low** for internal cloud infrastructure details (not publicly documented beyond "isolated container").

## Open Questions
- What container runtime does Codex cloud use? (Not disclosed)
- How does Codex handle state persistence across multi-agent workflows beyond CSV batch jobs?
- Will multi-agent support graduate from experimental? What roadmap?
- How does the `x-codex-turn-state` sticky routing work at scale?
- What is the actual failure/retry model for subagent hangs?
