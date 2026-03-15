# Claude Agent SDK & Claude Code: Multi-Agent Architecture Deep Dive

## 1. Architecture Overview

The Claude Agent SDK is the runtime that powers Claude Code, exposed as a library. Originally built as a coding tool runtime, it was generalized and renamed from "Claude Code SDK" in September 2025 [ENG1]. Available in Python (`claude-agent-sdk`) and TypeScript (`@anthropic-ai/claude-agent-sdk`).

The core abstraction is a **single-function entry point** (`query()`) that takes a prompt and options, then runs an autonomous agent loop: gather context, take action, verify, repeat. The SDK handles tool execution internally -- unlike the Anthropic Client SDK where the caller implements the tool loop, the Agent SDK manages the full agentic cycle [SDK1].

### Two Tiers of Multi-Agent Support

The system provides two distinct multi-agent models:

1. **Subagents** -- lightweight, hierarchical workers within a single session [CC1, SDK2]
2. **Agent Teams** -- full peer-to-peer coordination across independent sessions [CC2]

These are complementary but architecturally different. Subagents are the stable production mechanism; agent teams are experimental (require `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`).

---

## 2. Subagent Architecture (Stable)

### Spawning Model

Subagents are invoked through the **Agent tool** (renamed from Task tool in v2.1.63). When Claude encounters a task matching a subagent's `description` field, it delegates via the Agent tool. The tool accepts:
- `description`: natural language task
- `agent_type`: which subagent profile to use
- `model`: model override
- `allowed_tools`: tool subset
- `permission_mode`: permission behavior [DW1]

### Session & Context Isolation

Each subagent runs in its own **fresh conversation context**. Critical isolation properties:
- Subagent receives ONLY: its own system prompt + the Agent tool's prompt string + project CLAUDE.md
- Subagent does NOT receive: parent conversation history, parent system prompt, parent tool results, skills (unless explicitly listed)
- Only the subagent's **final message** returns to the parent as the Agent tool result
- Intermediate tool calls and results stay inside the subagent [SDK2]

This is strict one-way delegation: parent -> child -> result. No bidirectional communication during execution.

### Nesting Restriction

Subagents **cannot spawn other subagents**. This is enforced: including `Agent` in a subagent's tools list has no effect. The restriction prevents infinite nesting and runaway resource consumption [CC1, SDK2].

### Built-in Subagent Types

| Type | Model | Tools | Purpose |
|------|-------|-------|---------|
| Explore | Haiku (fast) | Read-only (no Write/Edit) | Codebase search and analysis |
| Plan | Inherits | Read-only | Research for plan mode |
| General-purpose | Inherits | All | Complex multi-step tasks |
| Bash | Inherits | Bash | Terminal commands in separate context |
| Claude Code Guide | Haiku | Read-only | Questions about Claude Code features |

### Custom Subagent Definition

Subagents are defined as Markdown files with YAML frontmatter, stored at:
- `.claude/agents/` (project scope, priority 2)
- `~/.claude/agents/` (user scope, priority 3)
- Plugin `agents/` directory (priority 4)
- `--agents` CLI flag (session scope, priority 1 -- highest) [CC1]

Programmatic definition via `AgentDefinition` objects in `query()` options is the recommended approach for SDK applications [SDK2].

### Foreground vs Background Execution

- **Foreground**: blocks main conversation; permission prompts pass through to user
- **Background**: runs concurrently; permissions pre-approved before launch; auto-denies non-pre-approved; `AskUserQuestion` fails (but subagent continues)
- `background: true` in frontmatter or "run this in the background" natural language
- `Ctrl+B` backgrounds a running task
- `/tasks` shows active background tasks
- `Ctrl+F` (double-press) kills all background agents [CC1, DW1]

### Resumption

Subagents can be **resumed** to continue where they left off. Each subagent gets a unique `agentId`. The parent captures the `session_id` and `agentId`, then passes `resume: sessionId` in subsequent `query()` calls. Full conversation history including tool calls is preserved [SDK2].

Transcripts stored at `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`. Cleaned up after 30 days by default.

### Auto-Compaction

Each subagent independently manages context limits. Auto-compaction triggers at ~95% capacity (configurable via `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`). Compaction events logged with `preTokens` count [CC1].

---

## 3. Agent Teams Architecture (Experimental)

### Components

| Component | Role |
|-----------|------|
| Team Lead | Main Claude Code session; creates team, spawns teammates, coordinates |
| Teammates | Independent Claude Code instances working on assigned tasks |
| Task List | Shared list with pending/in-progress/completed states and dependency tracking |
| Mailbox | Message-passing system for inter-agent communication |

Storage: `~/.claude/teams/{team-name}/config.json` (member array with name, agent ID, agent type) and `~/.claude/tasks/{team-name}/` [CC2].

### Key Differences from Subagents

| Dimension | Subagents | Agent Teams |
|-----------|-----------|-------------|
| Context | Own window; results return to caller | Own window; fully independent |
| Communication | Report back to parent only | Direct peer-to-peer messaging |
| Coordination | Parent manages all work | Shared task list with self-coordination |
| Token cost | Lower (summarized results) | Higher (each teammate is full Claude instance) |
| Nesting | No | No (teammates cannot spawn teams) |
| Session model | Within one session | Separate Claude Code sessions |

### Coordination Mechanisms

- **Task list**: shared, file-locked to prevent race conditions on claiming. Tasks support dependencies -- blocked tasks unblock automatically when dependencies complete.
- **Messaging**: `message` (point-to-point) and `broadcast` (all teammates). Messages delivered automatically.
- **Idle notifications**: teammates auto-notify the lead when they finish.
- **Plan approval**: teammates can be required to plan before implementing. Lead approves/rejects plans autonomously based on criteria in the prompt [CC2].

### Display Modes

- **In-process**: all teammates in main terminal; Shift+Down cycles between them
- **Split panes**: each teammate in own tmux/iTerm2 pane; requires tmux or iTerm2
- Default is `"auto"` (split if already in tmux, otherwise in-process) [CC2]

### Lifecycle

1. User requests team or Claude proposes one (requires user confirmation)
2. Lead creates team config and shared task list
3. Lead spawns teammates with specific spawn prompts
4. Teammates claim and work through tasks
5. Lead can assign, redirect, shut down teammates
6. Lead runs cleanup when done (must shut down teammates first)
7. Only the lead can run cleanup [CC2]

---

## 4. Worktree / Code Isolation Model

### Git Worktree Integration

`claude --worktree <name>` creates an isolated git worktree at `<repo>/.claude/worktrees/<name>` with branch `worktree-<name>`, branching from the default remote branch. Auto-generated names if omitted [CC4].

### Subagent Worktrees

Setting `isolation: worktree` in a subagent's frontmatter creates a temporary worktree for that subagent's entire session. All file operations are isolated from the main working directory. Auto-cleaned if no changes made [CC1, CC4].

### Cleanup Behavior

- No changes: worktree and branch removed automatically
- Changes exist: Claude prompts to keep or remove
- Keeping preserves directory and branch for later return [CC4]

### Cross-Worktree Sharing

Sessions in worktrees share project configs and auto-memory across worktrees of the same repository. CLAUDE.md is loaded from the worktree's working directory [CC2, CC4].

### Non-Git VCS

`WorktreeCreate` and `WorktreeRemove` hooks allow custom worktree creation for non-git VCS (SVN, Perforce, Mercurial). The hook must print the absolute path to stdout [CC5].

---

## 5. Message Transport & Communication

### Subagent Communication

Strictly hierarchical:
1. Parent sends prompt via Agent tool invocation
2. Subagent works autonomously (tool calls invisible to parent)
3. Subagent returns final message as Agent tool result
4. Parent may summarize before presenting to user

No mid-execution communication. No peer-to-peer between subagents.

### Agent Team Communication

Peer-to-peer via mailbox system:
- `message`: send to one specific teammate
- `broadcast`: send to all (cost scales with team size)
- Automatic delivery (no polling required)
- Teammates discover each other via `config.json` member array

### SDK Message Stream

The SDK exposes messages as an async iterator. Each message includes:
- `parent_tool_use_id`: identifies messages from within a subagent's execution context
- `session_id`: for session resumption
- `type`/`subtype`: for message classification

Detecting subagent invocation: check for `tool_use` blocks where `name` is `"Agent"` (or legacy `"Task"`) [SDK2].

---

## 6. Review / Landing Model

### No Built-in Review Pipeline

Unlike some frameworks, Claude Code does not enforce a review-before-merge pipeline. The model is:
1. Agent works in worktree or main directory
2. Agent can create commits and PRs via `gh pr create`
3. Session is linked to PR for later resumption via `claude --from-pr <number>`
4. Human reviews PR through normal git workflow

### Quality Enforcement via Hooks

Organizations enforce quality gates through hooks rather than built-in review:
- `TaskCompleted` hook: exit code 2 prevents task completion
- `TeammateIdle` hook: exit code 2 sends feedback and keeps teammate working
- `SubagentStop` hook: can prevent subagent from stopping
- `Stop` hook: can prevent Claude from finishing (e.g., "must fix failing tests before stopping")
- `PostToolUse` hook: can run linters after file edits [CC5]

### Plan Approval (Agent Teams)

Teammates can be required to plan before implementing. Lead reviews and approves/rejects plans autonomously. Rejected teammates revise and resubmit. This is the closest thing to a built-in review gate [CC2].

---

## 7. Operator Control & Permissions

### Permission Hierarchy (highest to lowest priority)

1. **Managed settings**: cannot be overridden by any level, including CLI args
2. **CLI arguments**: temporary session overrides
3. **Local project settings** (`.claude/settings.local.json`)
4. **Shared project settings** (`.claude/settings.json`)
5. **User settings** (`~/.claude/settings.json`)

Deny rules always win: if denied at any level, no other level can allow it [CC3].

### Permission Modes

| Mode | Behavior |
|------|----------|
| `default` | Prompts on first use of each tool |
| `acceptEdits` | Auto-accepts file edits |
| `plan` | Read-only analysis only |
| `dontAsk` | Auto-denies unless pre-approved |
| `bypassPermissions` | Skips all checks (dangerous; can be disabled by admins) |

### Managed Settings (Enterprise)

Administrators can deploy settings that cannot be overridden:
- `disableBypassPermissionsMode`: prevents dangerous mode
- `allowManagedPermissionRulesOnly`: prevents user/project permission rules
- `allowManagedHooksOnly`: prevents user/project/plugin hooks
- `allowManagedMcpServersOnly`: restricts MCP server sources
- `sandbox.network.allowManagedDomainsOnly`: restricts network access [CC3]

### Tool Restriction Syntax

Permission rules follow `Tool` or `Tool(specifier)` format:
- `Bash(npm run *)`: wildcard matching
- `Read(/src/**/*.ts)`: gitignore-style path patterns
- `WebFetch(domain:example.com)`: domain restriction
- `Agent(my-agent)`: subagent restriction
- `mcp__server__tool`: MCP tool targeting [CC3]

### Sandboxing

Complementary OS-level enforcement for Bash:
- Restricts filesystem and network access at OS level
- Applies only to Bash commands and child processes
- Filesystem restrictions use Read/Edit deny rules
- Network restrictions combine WebFetch rules with sandbox `allowedDomains`
- Defense-in-depth: even if prompt injection bypasses Claude's decision-making, sandbox restricts execution [CC3]

### CLAUDE.md

Project instructions loaded hierarchically:
- `~/.claude/CLAUDE.md` (global user instructions)
- Project-level `CLAUDE.md` or `.claude/CLAUDE.md`
- Subagents receive project CLAUDE.md via `settingSources`
- Agent team teammates load CLAUDE.md from their working directory
- Not a security boundary; serves as behavioral guidance [CC1, CC2]

---

## 8. Escalation Model

### Hook-Based Escalation Chain

The hooks system provides a multi-layered escalation mechanism:

1. **PreToolUse hook** (first line): can `allow`, `deny`, or `ask` immediately, bypassing permission system
2. **Permission system** (policy checks): if PreToolUse did not auto-decide
3. **PermissionRequest hook** (final approval): auto-approve/deny before user dialog
4. **User dialog** (manual approval): only if no hook auto-decided [CC5]

### Error Handling

- `PostToolUseFailure` hook: fires on tool execution errors; can add context for Claude
- `Stop` hook with exit code 2: prevents Claude from stopping, forcing continued work
- `SubagentStop` hook: can prevent subagent completion
- `TaskCompleted` hook: can block task completion in agent teams

### Notification Hooks

`Notification` event fires when Claude needs attention:
- `permission_prompt`: awaiting tool approval
- `idle_prompt`: done and waiting for input
- `auth_success`: authentication completed
- Supports desktop notifications via platform-native commands [CC4]

### No Built-in Agent-to-Human Escalation Protocol

There is no formal escalation mechanism from agent to human beyond:
1. Permission prompts (tool approval requests)
2. `AskUserQuestion` tool (clarifying questions, fails silently in background agents)
3. Notification hooks for attention routing

The system assumes human-in-the-loop through the permission system rather than explicit escalation protocols.

---

## 9. Comparison-Ready Dimensional Summary

| Dimension | Claude Agent SDK / Claude Code |
|-----------|-------------------------------|
| **Agent topology** | Hierarchical (subagents) + Peer mesh (agent teams) |
| **Spawning** | Agent tool invocation; markdown file definitions or programmatic AgentDefinition |
| **Context model** | Strict isolation; fresh context per subagent; only final result returns |
| **Communication** | One-way return (subagents) or peer mailbox (teams) |
| **Code isolation** | Git worktrees (automatic or configured) |
| **Nesting depth** | 1 level only; subagents cannot spawn subagents |
| **Built-in tools** | Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, AskUserQuestion |
| **External tools** | MCP protocol (stdio, http, sse, ws transports) |
| **Permission model** | 5-tier hierarchy; managed settings for enterprise; sandbox for OS-level enforcement |
| **Quality gates** | Hook-based (PreToolUse, PostToolUse, Stop, TaskCompleted) |
| **Review/merge** | No built-in pipeline; git workflow via gh CLI |
| **Escalation** | Permission prompts + hooks; no formal escalation protocol |
| **Session persistence** | JSONL transcripts; session resumption with full history |
| **Cost control** | Model selection per subagent (haiku/sonnet/opus); maxTurns limit |
| **Memory** | Persistent memory scopes (user/project/local) with MEMORY.md |
| **Maturity** | Subagents: stable/production; Agent teams: experimental |
