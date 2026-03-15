# Summary: Claude Agent SDK & Claude Code Multi-Agent Architecture

## Objective
Produce a structured architectural summary of the Claude Agent SDK and Claude Code's multi-agent system, suitable for comparison against CrewAI, AutoGen, LangGraph, and other agent swarm systems.

## Top Findings

### 1. Two-Tier Multi-Agent Model
The system provides two complementary but architecturally distinct multi-agent mechanisms:
- **Subagents** (stable): lightweight, hierarchical workers within a single session. Parent spawns child via the Agent tool; child works in isolated context; only final result returns. No peer-to-peer. Max nesting depth of 1.
- **Agent Teams** (experimental): full peer-to-peer coordination. Separate Claude Code instances with shared task list, mailbox messaging, and self-coordination. Each teammate is a complete independent session.

### 2. Strict Context Isolation
Every subagent/teammate gets its own fresh context window. Subagents receive only their system prompt, the task prompt, and project CLAUDE.md -- not the parent's conversation history or tool results. This prevents context pollution but means the parent must explicitly provide all needed information in the spawn prompt.

### 3. Git Worktree-Based Code Isolation
Parallel agents can work in isolated git worktrees (`isolation: worktree`), each with its own branch and file state. Auto-cleaned if no changes. This is the primary mechanism for preventing file conflicts in parallel work.

### 4. Hook-Based Quality and Permission Control
Rather than a built-in review pipeline, the system uses lifecycle hooks (PreToolUse, PostToolUse, Stop, TaskCompleted, TeammateIdle) to enforce quality gates, permission decisions, and continuation logic. Exit code 2 is the universal "block this action" signal. Hooks can allow, deny, or escalate to user.

### 5. Enterprise Permission Hierarchy
Five-tier permission precedence (managed > CLI > local project > shared project > user). Managed settings cannot be overridden. Deny rules always win. OS-level sandboxing provides defense-in-depth for Bash commands. This is significantly more sophisticated than open-source alternatives.

### 6. No Built-in Review/Merge Pipeline
Agents create commits and PRs via standard git tooling (gh CLI). Review and merge happen through normal git workflow. The system does not enforce code review before landing -- that is left to the organization's existing process.

## Recommendations
- Use this research alongside `../multi-agent-framework-comparison/` for the full comparative study
- The strict context isolation and no-nesting constraint are the most significant architectural differentiators vs. frameworks like CrewAI (which allows nesting) and AutoGen (which supports multi-hop conversations)
- Agent teams' task list + mailbox model is closest to AutoGen v0.4's GroupChat, but with file-system-based coordination rather than in-memory message passing
- The hook system is unique among the surveyed frameworks -- none of CrewAI, AutoGen, or LangGraph provide equivalent lifecycle interception

## Confidence Level
**High** for subagent architecture (stable, well-documented). **Medium** for agent teams (experimental, subject to change). All findings sourced from official Anthropic documentation retrieved 2026-03-15.

## Open Questions
- How agent teams handle merge conflicts when teammates edit related (but not identical) files
- Whether agent teams will support worktree isolation per-teammate (currently a known gap per GH#28175)
- SDK roadmap for subagent nesting (currently hard-limited to 1 level)
- Performance characteristics of the file-locked task list under high concurrency
- How persistent memory interacts with agent team teammates across sessions
