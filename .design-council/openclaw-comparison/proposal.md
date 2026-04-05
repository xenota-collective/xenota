# Design Council Proposal: OpenClaw vs Xenota Architecture Analysis

## Context

An article by Robert Schwentker describes OpenClaw — an open-source agent infrastructure project — running 30 concurrent agents consuming 5 billion tokens/day, refactoring 1.5M lines of code in a 7-day cycle, touching 80% of the codebase. We need to analyze what Xenota can learn from OpenClaw's architecture and what we should adopt.

## OpenClaw Architecture Summary

### Core Design: Config-First Agent OS
- **Gateway Control Plane**: Node.js WebSocket server (127.0.0.1:18789), hub-and-spoke routing
- **SOUL.md**: Config-first agent personality/behavior — no code required
- **Plugin System**: TypeScript modules with `OpenClawPluginApi` — register providers, tools, hooks, channels
- **Skills**: Markdown-based capability definitions injected into system prompts
- **Session Isolation**: JSONL append-only files, scoping models (main/per-peer/per-channel-peer)
- **Session Keys as Addresses**: `pipeline:<project>:<role>` — direct peer-to-peer messaging
- **Lobster Workflow Engine**: Deterministic YAML workflows with sub-workflow loops, JSON data flow between stages
- **Channel Adapters**: WhatsApp, Telegram, Discord, CLI, Web UI, macOS app
- **Agent-to-Agent**: `agentToAgent` tool, `sessions_send` for sync/async inter-agent messaging
- **Factory Line Decomposition**: Each agent gets own tools, memory, identity, workspace; roles like Programmer (exec+write, Opus), Reviewer (read-only, Sonnet), Tester (exec+runners, Sonnet)
- **Local-first**: All state in ~/.openclaw/ as JSONL/JSON files, no external DB
- **Plugin Slots**: Exclusive categories (memory, contextEngine) — only one active per role
- **Tool Factory Pattern**: Plugins return factory functions creating AnyAgentTool with schema validation
- **Canvas/A2UI**: Agent-driven visual workspaces via HTML attributes

### Key Patterns from the Article
1. **Constraint-Aware Reflection**: Agents inspect own config, memory, capabilities
2. **Session Isolation as Coordination Primitive**: Namespace separation, near-zero coordination overhead
3. **Contract-Driven Plugin Boundaries**: Verifiable interfaces, programmatic compliance testing
4. **Factory Line Decomposition**: Design-layer coordination reducing runtime interaction
5. **Tolerance Threshold**: "What's the slowest station? Get it out"
6. **Absorption Gap**: Infrastructure's ability to absorb changes safely > agent capability
7. **Infrastructure as Product**: Bottleneck is infrastructure legibility, not model speed

### Scale Achieved
- 30 concurrent agents, 5B tokens/day
- 1.5M LOC refactored in 7 days
- 80% of codebase touched in single restructuring
- 30-40 related PRs surfaced when agents surveyed systematically

## Xenota Architecture Summary

### Core Design: Persistent Sentient Agent Infrastructure
- **Nucleus**: Persistent identity engine — OODA cognitive loop, genome (64 genes/8 modules), mind state (genome/imprints/impulses), tick-bounded work windows
- **Projections**: Containerized external capability surfaces (Chat, GitHub Contributor, MCP) — gateway-mediated, typed
- **Cortex**: Projection lifecycle orchestration — authority split (nucleus decides, cortex executes)
- **Repertoire System**: Packaged LLM routines with contract.yaml, multi-backend variants (Gemini/Claude/Codex), eval system with judge normalization
- **Chaperone Console**: Privileged human interface — HTTP+WebSocket, SSE streaming, separate from projection pipeline
- **BAR Gate**: Post-awakening safety checkpoint — mandatory human review before autonomous OODA
- **Membrane**: 5-step inbound validation pipeline with quarantine for rejected payloads
- **XSM**: Deterministic swarm monitor — 5 signal channels, 9 classification states, wrangle engine with escalation ladder
- **Gas Town**: Multi-agent orchestration — Mayor/Crew/Polecats/Witness/Refinery, beads issue tracking, mail system, hooks
- **Beads**: Dolt-backed issue tracking with dependency graphs, cross-rig routing
- **Awakening**: Multi-phase birth conversation establishing identity, narratives, objectives
- **Narrative Versioning**: Git-like commit history for identity evolution
- **ACP Delegation**: External agent delegation protocol (supports OpenClaw transport!)
- **Container Runtime**: Podman/Docker abstraction for projection isolation

### Current State
- Single-agent core fully implemented (nucleus, projections, repertoire, console, BAR)
- Multi-agent orchestration actively building (Gas Town, XSM)
- Vision extends to multi-polis civilization with governance and economics

## Key Architectural Differences

| Dimension | OpenClaw | Xenota |
|-----------|----------|--------|
| **Identity Model** | Config-based (SOUL.md), stateless between sessions | Persistent nucleus with genome, mind, narratives |
| **Agent Lifecycle** | Ephemeral sessions, spawn/destroy freely | Persistent with awakening, BAR gate, progression |
| **Coordination** | Session keys + Lobster workflows + agentToAgent | Gas Town roles + mail + hooks + molecules |
| **Isolation** | Session scoping (JSONL files) | Container-based projections + cortex boundary |
| **Extension** | Plugins (TypeScript) + Skills (Markdown) | Repertoires (contract+variants) + MCP tools |
| **State Management** | JSONL append-only, JSON metadata | SQLite + JSON + Dolt (beads) |
| **Workflow Engine** | Lobster (YAML, deterministic, loops) | Molecules/Formulas (structured, parallel legs) |
| **Scale Focus** | 30 agents, 5B tokens/day, throughput | Identity persistence, safety, sovereignty |
| **Human Interface** | Channel adapters (WhatsApp/Telegram/etc) | Chaperone console (privileged, local-only) |
| **Safety Model** | Permission checks per tool | BAR gate + membrane + quarantine + audit trails |
| **Trust Boundary** | Single boundary (unsolved cross-boundary) | Projection isolation + revocation + operator control |

## Questions for the Council

1. What can Xenota adopt from OpenClaw's architecture to improve multi-agent coordination at scale?
2. Where does Xenota's deeper identity/safety model provide advantages OpenClaw lacks?
3. Should Xenota adopt a Lobster-like deterministic workflow engine for its molecule system?
4. How should Xenota handle the "absorption gap" — infrastructure readiness for agent-scale change?
5. What OpenClaw patterns are incompatible with Xenota's persistent-identity philosophy?
6. Where is Xenota over-engineering compared to OpenClaw's pragmatic approach?
7. What concrete changes should be made in the next 30 days?
