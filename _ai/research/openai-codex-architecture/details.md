# OpenAI Codex Agent Architecture: Detailed Findings

## 1. System Overview

Codex is OpenAI's coding agent product, available as both a cloud service (Codex web/cloud) and an open-source CLI tool (codex-cli). Both share a unified backend architecture via the **App Server**, a bidirectional protocol layer that decouples agent logic from client surfaces [TP1].

The system is powered by specialized models: `codex-1` (based on o3, optimized via RL on coding tasks), and more recently `gpt-5-codex` and `gpt-5.3-codex` [OB3]. GPT-5.3-Codex can work independently for 7+ hours on complex tasks.

## 2. Architecture: The App Server

### 2.1 Wire Protocol

The App Server uses **JSON-RPC streamed as JSONL over stdio** for local clients, and **HTTP/Server-Sent Events** for web clients [TP1]. This bidirectional protocol supports:

- Client-to-server requests (user messages, approvals)
- Server-to-client requests (approval prompts, where the server pauses a turn until receiving allow/deny)
- Backward compatibility: older clients can interact with newer server versions

### 2.2 Conversation Primitives

Three core primitives model all agent interactions [TP1]:

| Primitive | Description |
|-----------|-------------|
| **Item** | Atomic unit of input/output. Types: user message, agent message, tool execution, approval request, diff. Lifecycle: started -> delta (streaming) -> completed |
| **Turn** | Groups the sequence of Items from a single unit of agent work triggered by user input |
| **Thread** | Durable session container. Supports creation, resumption, forking, archival. Persisted event history allows reconnection without state loss |

### 2.3 Unified Surface

The same App Server powers all Codex experiences [TP1]:
- CLI (terminal TUI)
- VS Code extension
- Web app (chatgpt.com/codex)
- macOS desktop app
- JetBrains and Xcode integrations

Local clients bundle platform-specific binaries as child processes. The web runtime uses containers with HTTP/SSE.

## 3. Worker/Session Model

### 3.1 Cloud Execution

Each cloud task runs in its own **isolated container** [OC2]:

1. Container instantiated; repository checked out at specified branch/commit
2. Setup script executes (with internet access enabled during setup)
3. Internet access disabled for agent execution phase
4. Agent loop: edits code, runs checks, validates work
5. Results displayed with file diffs; user can open PRs or ask follow-ups

**Container caching**: Containers cache for up to 12 hours. Cache invalidates on setup script, secrets, or env var changes. Business/Enterprise caches are shared across workspace members [OC2].

**Automatic dependency installation** for npm, yarn, pnpm, pip, pipenv, poetry. Custom setup via Bash scripts for additional tooling [OC2].

**Key limitation**: Setup scripts run in a separate Bash session from the agent, so `export` commands do not persist. Use `~/.bashrc` or environment settings instead [OC2].

### 3.2 CLI Execution

The CLI runs locally with OS-level sandboxing [OC3, OC8]:
- **macOS**: Seatbelt (sandbox-exec profiles)
- **Linux**: Landlock (default), with optional Bubblewrap or seccomp
- No container abstraction -- direct process-level enforcement

Session management:
- Interactive mode with full-screen TUI, syntax highlighting, inline approval
- `codex resume` reopens earlier threads with same repo state
- `codex exec` for non-interactive scripting (pipes results to stdout)
- Transcript storage enables local resumption

### 3.3 Rust Implementation (codex-rs)

The CLI was rewritten from TypeScript/React/Node to **Rust** for [TP2]:
- Zero-dependency installation (no Node v22+ requirement)
- Native security bindings for Linux sandboxing
- No runtime GC, lower memory consumption
- Extensible wire protocol for multi-language agent extensions

The `codex-rs/` workspace contains 65+ Cargo crates. Key components [TP2]:
- `codex-core`: Central business logic (Codex struct, Session, ThreadManager, ModelClient)
- `ModelClient`: Session-scoped; manages WebSocket vs HTTP/SSE transport selection
- `ModelClientSession`: Turn-scoped; sends requests to OpenAI Responses API with sticky routing via `x-codex-turn-state` header for multi-turn session affinity

## 4. Sandboxing Model

### 4.1 Sandbox Modes

Three modes control what the agent can do autonomously [OC3, OC5]:

| Mode | Reads | Writes | Commands | Network |
|------|-------|--------|----------|---------|
| `read-only` | Yes | Approval required | Approval required | No |
| `workspace-write` (default) | Yes | Workspace only | Within boundaries | Configurable |
| `danger-full-access` | Yes | Unrestricted | Unrestricted | Yes |

### 4.2 Approval Policies

Layered on top of sandbox modes [OC5, OC6]:

| Policy | Behavior |
|--------|----------|
| `untrusted` | Auto-approves known-safe ops; requires approval for state mutations |
| `on-request` | Works autonomously; pauses when exceeding sandbox boundaries |
| `never` | No approval prompts (use with caution) |

Auto-rejection policies allow administrators to automatically deny specific categories:
```toml
approval_policy = { reject = { sandbox_approval = true, rules = false, mcp_elicitations = false } }
```

### 4.3 Protected Paths

Even in writable modes, these remain read-only [OC5]:
- `.git` directories (including pointer files)
- `.agents` and `.codex` directories

### 4.4 Cloud vs CLI Sandbox Differences

| Aspect | Cloud | CLI |
|--------|-------|-----|
| Isolation | OpenAI-managed containers | OS-level enforcement (Seatbelt/Landlock) |
| Network | Disabled during execution by default | Configurable per sandbox mode |
| Setup | Separate Bash session with internet | Local environment |
| Persistence | Container cached up to 12h | Local filesystem |

## 5. Multi-Agent Coordination

### 5.1 Built-in Multi-Agent System

Codex has an experimental multi-agent capability enabled via `features.multi_agent` [OC4, OC6]. Key tools:

- **`spawn_agent`**: Creates a sub-agent for a specific task
- **`spawn_agents_on_csv`**: Batch processing -- reads CSV, spawns one worker per row, waits for batch completion, exports combined results

Each worker must call `report_agent_job_result` exactly once; workers that exit without reporting are marked as errors [OC4].

### 5.2 Agent Roles

Agents are defined with specialized configurations [OC6]:

```toml
[agents.worker]
config_file = "worker.toml"
description = "Execution-focused for small, targeted fixes"

[agents.explorer]
config_file = "explorer.toml"
description = "Read-heavy analysis agent"

[agents.monitor]
config_file = "monitor.toml"
description = "Task polling and status checks"
```

Built-in roles: `default`, `worker`, `explorer`, `monitor` [OC4].

### 5.3 Coordination Controls

| Setting | Purpose | Default |
|---------|---------|---------|
| `agents.max_threads` | Max concurrent open threads | 6 |
| `agents.max_depth` | Max nesting depth (root = 0) | 1 |
| `agents.job_max_runtime_seconds` | Per-worker timeout | 1800 (30 min) |
| `max_concurrency` | CSV batch parallelism | Unspecified |

### 5.4 Communication Model

Agents communicate through [OC4]:
- **Direct instruction routing**: Parent sends instructions to child agents at spawn time
- **Result aggregation**: Parent collects results before returning consolidated response
- **Monitor role**: Supports `wait` tool with long polling windows (up to 1 hour per call)

There is **no peer-to-peer agent communication**. The model is strictly hierarchical: parent spawns children, children report back. No shared memory or message bus exists between sibling agents.

### 5.5 Agents SDK Integration

Codex can also run as an **MCP (Model Context Protocol) server** [OC10], enabling integration with the OpenAI Agents SDK:

```bash
codex mcp-server  # Keeps Codex alive across multiple agent turns
```

Two MCP tools exposed:
- `codex`: Initiates a new session (with prompt, approval-policy, sandbox, model, cwd params)
- `codex-reply`: Continues an existing session via threadId

This enables external orchestration patterns where a **Project Manager agent** coordinates specialized agents (Designer, Frontend Dev, Backend Dev, Tester) via the Agents SDK, each calling into Codex MCP for execution [OC10].

## 6. Repo Model and Code Change Management

### 6.1 Cloud

- Repository loaded via GitHub integration at task start [OC2]
- Agent works on checked-out branch/commit within its container
- Changes produced as diffs visible to user after task completion
- User can instruct Codex to open a PR, which auto-fills description [OC9]
- `@codex` mention in GitHub comments triggers cloud tasks
- `@codex review` on PRs triggers standard GitHub code review [OC9]

### 6.2 CLI

- Operates directly on local working directory
- Changes applied to local filesystem
- User manages git operations (branching, committing, pushing)
- `/review` command for local code review

### 6.3 Known Limitation

Branch management in cloud Codex is inconsistent -- follow-up requests may update the existing branch or create a new one unpredictably.

## 7. Operator Control

### 7.1 Configuration Hierarchy

Codex uses TOML configuration with multiple injection points [OC6]:

- `model_instructions_file`: Replaces built-in instructions (overrides AGENTS.md)
- `developer_instructions`: Additional instructions injected into sessions
- `AGENTS.md` files in repository: Default instruction source
- Per-agent config files via `agents.<name>.config_file`

### 7.2 Feature Gates

Operators can toggle capabilities [OC6]:
- `features.multi_agent`: Enable/disable spawn tools
- `features.shell_tool`: Enable/disable command execution
- `features.web_search`: `disabled`, `cached`, or `live`
- `features.unified_exec`: PTY-backed execution

### 7.3 Enterprise Controls

- Admin setup via organizational policies [OC5]
- OpenTelemetry integration for compliance tracking
- Captures: tool approval decisions, sandbox/policy changes, execution outcomes and durations

## 8. Escalation and Error Handling

### 8.1 Designed Escalation Path

The approval flow is the primary escalation mechanism [OC5]:
- When agent hits sandbox boundary, it pauses and requests approval
- Server sends approval request to client (bidirectional protocol)
- Turn pauses until client responds with allow/deny
- Auto-rejection policies can preemptively deny certain categories

### 8.2 Known Weaknesses

Based on GitHub issues and community reports:
- **Stuck approvals**: UI can lose sync with backend executor, leaving tasks permanently blocked
- **Missing escalation**: Agent sometimes reports network failures but does not request elevated permissions
- **Model bailout**: Under load, model may skip commands and tell user to run tests manually
- **Subagent hangs**: No automatic timeout or retry for stuck subagents; sessions can hang indefinitely
- **No structured error recovery protocol**: Agent relies on model reasoning to detect and handle errors rather than a formal state machine

## 9. Comparative Observations

### 9.1 What Codex Is

Codex is a **product-grade, single-agent-primary system** with experimental multi-agent extensions. It is not a general-purpose multi-agent framework like CrewAI, AutoGen, or LangGraph. Its strengths:

- Deep sandbox isolation (both cloud containers and OS-level local enforcement)
- Unified protocol (App Server) across all surfaces
- Direct GitHub integration for PR workflows
- Long-running autonomous execution (7+ hours with GPT-5.3-Codex)

### 9.2 What Codex Is Not

- **Not a swarm system**: No peer-to-peer communication, no emergent coordination, no shared state between agents
- **Not a general orchestration framework**: Multi-agent is hierarchical parent-child only, max depth 1 by default
- **Not a message bus architecture**: Communication is instruction-at-spawn + result-at-completion, not ongoing message passing
- **Not pluggable for arbitrary agent types**: Workers are Codex instances with different configs, not heterogeneous agent implementations

### 9.3 Comparison to Multi-Agent Frameworks

| Dimension | Codex | CrewAI | AutoGen | LangGraph |
|-----------|-------|--------|---------|-----------|
| Primary design | Coding agent product | Multi-agent framework | Multi-agent framework | Agent workflow graphs |
| Coordination | Hierarchical spawn/collect | Sequential/hierarchical crews | Conversation-based | Graph-based state machines |
| Agent communication | Instruction + result only | Delegated messages | Chat threads | State transitions |
| Peer-to-peer | No | Limited (delegation) | Yes (GroupChat) | Via graph edges |
| Sandbox isolation | Deep (containers, OS-level) | None built-in | None built-in | None built-in |
| Code execution | Core capability | Via tools | Via Docker executor | Via tools |
| Production readiness | High (OpenAI-hosted) | Medium | Medium | Medium-High |
