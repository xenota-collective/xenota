# Coding Agent Architectures: Detailed Findings

## 1. Devin (Cognition Labs)

### Architecture Overview
Devin is a fully hosted, asynchronous coding agent. Each session runs in an isolated cloud VM provisioned with a shell, VS Code-style editor, and Chrome browser instance. Cognition has moved from using frontier foundation models (GPT-4 Turbo) to proprietary agent models (SWE-1.5, SWE-grep) optimized for software engineering. Following their acquisition of Windsurf in July 2025, these models are also available inside the Windsurf IDE for lower-latency in-IDE use.

### Worker/Session Model
- Each session spins up an isolated "cloud laptop" VM (referred to as a "Devin Brain container").
- Sessions are fully stateless from the platform's perspective -- no data persists outside the customer's environment.
- A memory layer stores vectorized snapshots of the codebase plus a full replay timeline of every command, file diff, and browser tab.
- VPC deployment option allows running Devin VMs inside customer infrastructure for firewall access.
- Multiple Devins can run in parallel, each in its own isolated VM. [devin-02]

### Coordination Model
- Devin is primarily a single-agent system with parallelization at the session level (N independent Devins, not coordinated multi-agent).
- No documented inter-agent coordination protocol. Each Devin works independently on its assigned task.
- Playbooks and Knowledge provide shared context across sessions but are not a coordination mechanism.

### Message Transport
- REST API (v3) at api.devin.ai for programmatic session management.
- Slack integration for conversational task assignment.
- GitHub integration for PR-triggered workflows (Devin Review, automated PR reviews via Actions).
- Chat-based interface in the Devin webapp for interactive sessions.

### Repo/Worktree Model
- Devin clones the repository into its VM workspace.
- Creates feature branches for changes.
- Each session operates on its own branch -- no worktree abstraction documented.
- Devin Review uses git worktrees on the review side (CLI creates worktree in cached dir to check out PR branch without disturbing local working directory). [devin-06]

### Review/Landing
- Devin opens PRs on GitHub. Human review and approval still required.
- Devin Review provides structured code review with logical grouping of changes, copy/move detection.
- Review comments sync bidirectionally with GitHub.
- Branch protection and team ownership rules remain enforced. [devin-06]
- ~67% PR merge rate as of November 2025 (up from ~34%). [devin-01]

### Operator/User Control
- **Playbooks**: Step-by-step task procedures with success criteria and guardrails. Shareable within teams. [devin-03]
- **Knowledge**: Persistent organizational context (style guides, conventions) recalled automatically by Devin. [devin-03]
- **Secrets management**: Via API for credential injection.
- **Control Options**: Configurable in PR comments for execution customization.
- **VPC deployment**: Enterprise control over where VMs run. [devin-05]

### Escalation
- Devin can pause and ask questions in the chat interface when blocked.
- No documented formal escalation protocol with severity levels or routing.
- Human-in-the-loop pattern: Devin presents its plan, humans can steer mid-execution.

### Multi-Agent / Swarm
- Parallel independent sessions (fleet of Devins), not coordinated swarm.
- No inter-agent communication or task decomposition across agents.

---

## 2. SWE-agent (Princeton NLP)

### Architecture Overview
SWE-agent is an open-source, academically-originated system (NeurIPS 2024) that turns LLMs into software engineering agents via an Agent-Computer Interface (ACI). The core innovation is designing LM-friendly commands and feedback formats rather than having the model use raw shell commands. Now in maintenance-only mode; mini-swe-agent (100 lines, 74%+ on SWE-bench Verified) is the recommended successor. [swe-01, swe-02]

### Worker/Session Model
- Central entry point: `sweagent` CLI executable.
- `SWEEnv` class manages the execution environment as a thin wrapper around SWE-ReX.
- SWE-ReX starts a Docker container (default), AWS Fargate, Modal, or local execution.
- Within the container, a shell session executes commands.
- Communication happens via a server running inside the container. [swe-02, swe-03]

### Sandboxing
- Docker containers (default) with optional gVisor for untrusted execution.
- Ephemeral containers with configurable execution timeouts.
- Custom container images supported (e.g., Ubuntu 24.10 with npm).
- Cross-tenant isolation via container boundaries. [swe-03]

### Coordination Model
- Strictly single-agent. No multi-agent coordination.
- One agent loop per session: prompt model -> parse action -> execute -> observe -> repeat.

### Message Transport
- No external message transport. CLI-driven, single-process architecture.
- History sent to LM includes all prompts, actions, and outputs.
- `HistoryProcessor` compresses conversation history for context window efficiency. [swe-02]

### Repo/Worktree Model
- Repository cloned into the Docker container.
- Agent operates directly on the cloned repo within the container.
- No worktree abstraction. Changes are made in-place.
- Patches extracted as diffs for evaluation.

### Review/Landing
- Not part of SWE-agent's scope. It produces patches/diffs.
- Designed for benchmark evaluation (SWE-bench), not production PR workflows.
- Integration into CI/CD is left to the operator.

### Operator/User Control
- YAML configuration for agent behavior, tools, and model selection.
- Custom tool definitions (ACI elements) installed into the shell.
- Configurable deployment targets (Docker, AWS, Modal).
- No runtime operator intervention -- runs to completion or timeout.

### Escalation
- None. Agent runs autonomously until it produces a patch or exhausts retries/timeout.
- No human-in-the-loop mechanism.

### Multi-Agent / Swarm
- Single-agent only. No swarm support.
- SWE-ReX enables massive parallelization of independent runs (for benchmarking), but each run is an isolated single agent.

---

## 3. Cursor Agent Mode

### Architecture Overview
Cursor is a full VS Code fork (not a plugin) with native agent capabilities. The agent can plan multi-file changes, run terminal commands, apply diffs, and verify correctness. Cursor 2.0 (October 2025) introduced an agent-first architecture. The system indexes the codebase using hashed file structures for efficient change tracking. [cursor-02, cursor-03]

### Worker/Session Model
- **Foreground agents**: Run in the IDE, interactive, user can steer.
- **Background agents** (February 2026): Run in isolated Ubuntu VMs with internet access. Create branches and PRs autonomously. ~35% of Cursor's own PRs come from cloud agents. [cursor-03]
- **Parallel agents**: Up to 8 concurrent agents per prompt via git worktrees, up to 20 worktrees per workspace. [cursor-01]

### Sandboxing
- macOS: Seatbelt (Apple's sandbox framework).
- Linux: Landlock (kernel security module).
- Windows: OS-level sandboxing.
- Agents run freely within sandbox boundaries; permission requests surface only for operations outside boundaries (typically internet access). [cursor-05]
- Shell tool descriptions communicate sandbox constraints directly to the model, including accessible paths and how to request elevation.

### Coordination Model
- Parallel agents are independent (no inter-agent coordination).
- Cursor 2.5 (February 2026): async subagents that can spawn their own subagents, creating a tree of coordinated work. This is the closest to multi-agent coordination in this comparison.
- No documented message-passing between agents.

### Message Transport
- In-IDE communication (foreground).
- Background agents: results delivered as PRs.
- Automations: triggered by external events (Slack, Linear, GitHub, PagerDuty, webhooks). [cursor-03]
- No inter-agent message bus.

### Repo/Worktree Model
- Git worktrees are the core isolation mechanism for parallel agents.
- Each agent gets its own worktree with separate HEAD and index.
- New files and edited files from the primary working tree are synced to worktrees at launch. Git-ignored files excluded. [cursor-01]
- Setup scripts configurable via `.cursor/worktrees.json` (OS-specific commands for deps, env, migrations).

### Review/Landing
- "Apply" button merges worktree changes back to primary branch.
- Clean merge attempted first; "Full Overwrite" available for sequential application.
- Native conflict resolution UI for competing changes. [cursor-01]
- Background agents create PRs for human review.
- No autonomous merge -- human approval required.

### Operator/User Control
- `.cursorrules` file for project-specific instructions.
- YOLO mode: auto-approves terminal commands matching specified patterns (recommended only for safe/reversible commands). [cursor forum]
- Sandbox constraints communicated to model; agents request elevation when needed.
- Automations configurable with triggers and instructions.

### Escalation
- Agent asks for human approval when hitting sandbox boundaries.
- Updated shell tool rendering labels sandbox constraints and suggests escalation paths.
- No formal severity-based escalation framework.
- YOLO mode bypasses approval for whitelisted commands.

### Multi-Agent / Swarm
- Parallel independent agents via worktrees (up to 8).
- Subagent spawning (2.5) creates tree-structured work decomposition.
- Not a true swarm -- no peer-to-peer agent communication or shared state.

---

## 4. Google Jules

### Architecture Overview
Jules is an asynchronous coding agent powered by Gemini (2.5 Pro, later 3 Pro). It integrates directly with GitHub repositories, cloning codebases into secure Google Cloud VMs. Designed for background task execution -- bug fixes, test writing, dependency updates. Exited public beta in August 2025. [jules-01, jules-02]

### Worker/Session Model
- Each task runs in a dedicated, ephemeral Google Cloud VM.
- VMs are destroyed after task completion (success or failure).
- No persistent containers, shared volumes, or long-lived processes.
- Session reuse optimization: "faster task execution by reusing prior setups." [jules-02]
- Jules Tools CLI brings agent interaction into the terminal.

### Sandboxing
- Full VM isolation per task on Google Cloud.
- No cross-contamination between runs.
- Data stays within isolated execution environment.
- Private by default; no training on user code. [jules-02]

### Coordination Model
- Parallel task execution supported (multiple background tasks simultaneously).
- Google AI Ultra tier advertised for "large-scale, multi-agent support."
- Gemini CLI extension enables multi-tasking orchestration. [jules-03]
- Details of inter-agent coordination are sparse.

### Message Transport
- GitHub integration: tasks triggered from issues, PRs delivered as output.
- Jules Tools CLI for terminal-based interaction.
- Gemini CLI extension for programmatic task management.
- No documented inter-agent message protocol.

### Repo/Worktree Model
- Repository cloned into the ephemeral VM.
- Changes produced as diffs.
- Each issue addressed in its own isolated environment.
- No worktree abstraction documented -- isolation is at the VM level.

### Review/Landing
- Jules presents: plan, reasoning, and diff of changes.
- Developer reviews and approves before merging.
- Plan modifiable before, during, and after execution.
- Changes delivered as GitHub PRs.
- No autonomous merge. [jules-01, jules-02]

### Operator/User Control
- Plan review and modification at all stages.
- Multimodal input support (beyond text).
- Task assignment via GitHub issues or CLI.
- Limited documented configuration/customization compared to Devin's Playbooks/Knowledge.

### Escalation
- Jules shows plan and reasoning, waits for approval.
- Plan can be modified mid-execution.
- No documented formal escalation protocol.

### Multi-Agent / Swarm
- Parallel independent tasks in separate VMs.
- Ultra tier hints at multi-agent orchestration but details are not public.
- Not a documented swarm architecture.
