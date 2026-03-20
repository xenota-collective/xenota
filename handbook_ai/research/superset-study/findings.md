# Superset Study: superset-sh/superset for Multi-Xenon Orchestration

**Bead**: xc-supersetstudy
**Date**: 2026-03-20
**Status**: Complete

## Executive Summary

`superset-sh/superset` is **not** Apache Superset (the BI/analytics platform). It is an
entirely separate project: an Electron-based desktop IDE designed to orchestrate multiple
CLI-based AI coding agents in parallel. Launched March 1, 2026, it has 7.5k GitHub stars
and adoption at Amazon, Google, ServiceNow, and Y Combinator startups.

**Verdict for multi-xenon orchestration**: Superset solves a **related but different
problem**. It orchestrates coding agents (Claude Code, Codex, etc.) for software
development tasks. Xenon orchestration requires managing autonomous agents with
persistent identity, OODA loops, projections, and membrane boundaries — a fundamentally
different runtime model. However, Superset's architecture contains patterns worth
studying for inspiration.

---

## What Superset Actually Is

**"The Terminal for Coding Agents"** — a desktop app that:
- Runs 10+ CLI coding agents simultaneously on one machine
- Isolates each agent in its own git worktree (automatic branch + directory creation)
- Provides unified monitoring, notifications, and diff review
- Works with any CLI agent: Claude Code, Codex, Cursor, Gemini CLI, OpenCode, etc.
- Deep-links to IDEs (VS Code, Cursor, JetBrains, Xcode, Sublime)

### Tech Stack
- **Runtime**: Electron + Bun
- **Frontend**: React + TailwindCSS + Vite
- **Backend**: tRPC (type-safe IPC)
- **Database**: Drizzle ORM + Neon (PostgreSQL)
- **Build**: Turborepo monorepo
- **License**: Elastic License 2.0 (ELv2) — NOT Apache 2.0 despite some claims

### Core Architecture
```
superset/
├── apps/           # Electron desktop app
├── packages/       # Shared packages (monorepo)
├── .agents/        # Agent command configurations
├── .superset/      # Per-repo config
├── scripts/        # Build utilities
└── tooling/        # TypeScript config
```

Per-repository config in `.superset/config.json`:
```json
{
  "setup": ["./.superset/setup.sh"],
  "teardown": ["./.superset/teardown.sh"]
}
```

Setup/teardown scripts receive: `SUPERSET_WORKSPACE_NAME`, `SUPERSET_ROOT_PATH`.

---

## Key Architectural Patterns

### 1. Git Worktree Isolation
Each agent task gets its own worktree with dedicated working directory, branch, and
staging area. Worktrees share the git object store (fast creation, minimal disk overhead).
This prevents file conflicts, branch collisions, and git index contamination.

**Gas Town parallel**: This is exactly what `gt worktree` does for crew/polecat
isolation. Superset automates the lifecycle (create → assign → monitor → teardown).

### 2. Agent-Agnostic Subprocess Model
Agents are spawned as subprocesses communicating via terminal I/O. No proprietary
protocol — if it runs in a terminal, it works. This is the same model Gas Town uses
with Claude Code sessions.

### 3. Session Persistence
A daemon maintains agent sessions across crashes. Sessions survive disconnects and
can be resumed.

### 4. Unified Monitoring Dashboard
Real-time status for all agents: running, completed, waiting for input. Notification
system alerts when attention is needed.

### 5. Integrated Diff Review
Built-in diff viewer with syntax highlighting and side-by-side comparison. Eliminates
context-switching to external git tools.

### 6. Port Management
Automatic port forwarding/allocation for services running in isolated environments
(3000→3001→3002 incrementing).

---

## Fit Assessment: Multi-Xenon Orchestration

### What "Multi-Xenon Orchestration" Requires

A xenon is a persistent autonomous agent with:
- **Nucleus**: identity, memory, objectives, OODA decision loop
- **Projections**: external capability surfaces (untrusted environments)
- **Membrane**: security boundary between projections and core cognition
- **Chaperone console**: local HTTP/WS server (127.0.0.1:7600) for human interface
- **Repertoire runtime**: cognitive routines and capability contracts
- **Persistent identity**: survives restarts, maintains continuity of self

Multi-xenon orchestration means:
1. Launching/stopping multiple xenon instances
2. Monitoring their OODA loops, strands, dispatches, projections
3. Inspecting their mind state, objectives, journal entries
4. Sending commands (projection lifecycle, overrides, objective management)
5. Viewing cross-xenon interactions and polis-level coordination
6. Managing awakening sequences across instances

### Where Superset Fits

| Requirement | Superset | Gap |
|---|---|---|
| Parallel agent spawning | Yes (git worktree isolation) | Xenons need persistent identity, not ephemeral worktrees |
| Agent monitoring | Yes (status dashboard) | Xenon monitoring needs OODA/strand/dispatch-level visibility |
| Agent communication | Terminal I/O only | Xenons expose HTTP/WS APIs with structured endpoints |
| Session persistence | Yes (daemon) | Xenon nuclei are already persistent processes |
| Task assignment | Yes (per-agent prompts) | Xenons self-direct via objectives, not external prompts |
| Diff review | Yes (built-in) | Xenons don't primarily produce code diffs |
| Security boundaries | None (trusts agents) | Xenon membrane model requires untrusted input isolation |
| Identity management | None | Core xenon requirement |
| Cross-agent coordination | None | Polis/hub coordination is a key multi-xenon need |

### Verdict

**Superset is not suitable as a multi-xenon orchestration platform.** The mismatch is
fundamental:

- **Superset model**: Ephemeral coding agents doing discrete tasks → produce diffs → human reviews → merge
- **Xenon model**: Persistent autonomous agents with identity, memory, OODA loops → continuous operation → projection-mediated interaction

Superset treats agents as **tools** (spawn, assign task, collect output, discard).
Xenons are **entities** (awaken, maintain identity, self-direct, persist).

### What IS Worth Borrowing

1. **Worktree automation lifecycle**: Superset's create→assign→monitor→teardown pattern
   for git worktrees is clean. Gas Town already does this but could study Superset's
   2-second provisioning and daemon-based session persistence.

2. **Unified monitoring UX**: The real-time dashboard pattern for multiple concurrent
   agents is directly relevant. A multi-xenon dashboard would need the same at-a-glance
   status with drill-down capability, but showing OODA state instead of terminal output.

3. **Notification system**: "Alert when attention needed" maps well to xenon override
   requests, strand blocks, and chaperone-required events.

4. **Port management**: Automatic port allocation for concurrent xenon consoles
   (currently hardcoded to 7600) is a solved problem in Superset.

---

## Alternatives for Multi-Xenon Orchestration

Given the mismatch, what should we actually build?

### Option A: Extend Chaperone Console (Recommended)
The chaperone console already exposes the right API surface per-xenon. A multi-xenon
orchestrator would be a **meta-console** that:
- Discovers running xenon instances (via `$XENON_HOME/console.json` discovery files)
- Aggregates their state endpoints into a unified dashboard
- Proxies commands to individual xenon consoles
- Shows cross-xenon interactions

This is the natural extension of existing architecture.

### Option B: Hub as Orchestration Surface
The Hub (planned) is already designed for "identity-aware coordination, service
discovery, work orchestration." Multi-xenon orchestration could be a Hub capability
rather than a separate tool.

### Option C: Grafana/Prometheus for Monitoring + Custom Control Plane
Use commodity monitoring for observability (OODA tick rates, strand counts, projection
health) and build a thin custom control plane for commands. Lower UX ambition but
faster to ship.

---

## Community Feedback (from HN Discussion)

Key concerns raised about Superset that are also relevant to multi-xenon orchestration:

1. **Review bottleneck**: "Converting typing time into reading time, which is usually
   worse." Applies to monitoring multiple autonomous xenons — the human becomes the
   bottleneck.

2. **Resource constraints**: Running 10 agents with separate environments strains
   hardware. Multiple xenon nuclei each running LLM inference would be heavier.

3. **Task decomposition difficulty**: "Most developers don't have ten crystal clear
   tasks." For xenons this maps to: defining meaningful independent objectives that
   don't create coordination overhead exceeding the parallelism benefit.

4. **Merge conflict risk**: File-level conflicts from parallel work. For xenons with
   projections, the equivalent is resource contention on shared external services.

---

## Recommendations

1. **Close this investigation** — Superset is not a fit for multi-xenon orchestration.
   The name collision with Apache Superset caused initial confusion, but the actual
   product (AI coding agent IDE) solves a different problem.

2. **File a follow-up bead** for multi-xenon dashboard design that borrows Superset's
   UX patterns (monitoring, notifications, at-a-glance status) applied to xenon-native
   concepts (OODA state, strands, projections, membrane events).

3. **File a follow-up bead** for xenon console port allocation — currently hardcoded
   to 7600, needs dynamic allocation for multi-instance operation.

4. **Study Superset's source** for git worktree automation if Gas Town wants to improve
   `gt worktree` provisioning speed and daemon-based session resilience.
