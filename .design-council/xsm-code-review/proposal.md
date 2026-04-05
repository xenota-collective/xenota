# XSM Comprehensive Code Review — Product + Technical

## What is XSM?

XSM (Xenota Swarm Manager) is a deterministic monitoring, classification, and intervention system for coordinating AI coding agents in a swarm. It runs as a control plane that observes worker agents via tmux, classifies their states, decides on interventions, and actuates those interventions — all while maintaining an audit trail.

## Codebase Facts

- **Location**: xenon/packages/xsm/
- **Source**: 22 files, ~12K lines in src/xsm/
- **Tests**: 24 files, ~17K lines in tests/
- **Dependencies**: click, pyyaml (runtime); pytest, black, flake8 (dev)
- **Persistence**: SQLite for state, JSONL for audit logs
- **Execution surface**: tmux panes
- **Entry point**: `xsm` CLI via Click

## Source File Map (by size)

| File | Lines | Purpose |
|------|-------|---------|
| main.py | 2,947 | CLI commands, orchestration, operator session mgmt |
| state.py | 1,477 | SQLite persistence, lifecycle state machine, leases, gates |
| wrangle.py | 1,076 | Deterministic decision engine, intervention ladder dispatch |
| tmux.py | 1,025 | Pane capture, normalization, regex patterns, option read/write |
| monitor.py | 744 | Snapshot generation, notification system, escalation artifacts |
| visualize.py | 587 | ASCII tables, Mermaid diagrams, swarm view rendering |
| strategy.py | 512 | Strategy YAML loading, intervention config, lifecycle policies |
| actuator.py | 504 | Tmux write primitives, TUI family detection, prompt delivery |
| classifier.py | 439 | Worker state classification (17 states), deterministic dispatch |
| audit.py | 438 | Append-only JSONL audit logging, run lifecycle |
| release.py | 413 | Release artifacts, Homebrew formula, man pages |
| evidence.py | 341 | Evidence-based progress detection (git, bead, test signals) |
| config.py | 306 | YAML config loading, path resolution, schema |
| qa.py | 278 | QA verdict schema, landing gates, sensitive change detection |
| backlog.py | 247 | Backlog item hierarchy, assignment finding, filtering |
| intervention.py | 155 | InterventionTracker: ladder position, cooldowns, exhaustion |
| hooks.py | 130 | Lifecycle hook system, event dispatch |
| signals.py | 123 | Signal dataclasses (tmux, process, status_tuple, git, bead, progress) |
| messages.py | 120 | Intervention message templates, MessageProvider protocol |
| repertoire_bridge.py | 63 | Subprocess bridge to xr CLI routines |

## Architecture Summary

### Core Control Loop
1. **Monitor** captures tmux pane state → builds WorkerSignals
2. **Classifier** maps signals → WorkerState (17 states, deterministic)
3. **Wrangle engine** dispatches to registered StateActionHandlers → WrangleDecision
4. **InterventionTracker** manages per-agent ladder position, cooldowns, budget
5. **Actuator** delivers interventions via tmux send-keys (TUI-family-aware)
6. **Audit** logs every decision to append-only JSONL

### Key Abstractions
- **WorkerSignals**: 7-channel composite input (tmux, process, status_tuple, git, bead, progress, observed_at)
- **WorkerState**: 17-variant enum (active, idle, blocked, handoff, terminal groups)
- **WrangleAction**: 6 action types (skip, nudge, reset_and_assign, call_repertoire, escalate, restart_session)
- **InterventionTracker**: Per-agent ladder walk with cooldowns and budget exhaustion
- **SwarmState**: Persisted agents dict + interventions dict
- **StrategyConfig**: Policy YAML with ladder, lifecycle, detection, assignment config
- **LeaseRecord**: Bead-agent-worktree authority fencing with control epochs

### State Handler Registry (wrangle.py)
- Protocol-based dispatch: WorkerState → StateActionHandler
- 10 handler implementations covering all 17 states
- Handlers registered at module load time into `_state_handlers` dict
- Cross-cutting invalidation check bypasses handlers for assignment status changes

### Lifecycle State Machine (state.py)
```
open → assigned → isolated → active → reviewing → verifying → resolved
  \→ failed, escalated (terminal exit states)
```
- Explicit ALLOWED_LIFECYCLE_TRANSITIONS graph
- Human gates at product/design/qa/landing phases
- Admission and alignment artifact validation gates

### Signal Channels
1. TmuxSignal: session alive, pane PID, output changes, capture timestamp
2. ProcessSignal: driver alive, child count, CPU active
3. StatusTupleSignal: explicit [XSM-STATUS] declarations from workers
4. GitSignal: branch, uncommitted changes, ahead count
5. BeadSignal: bead existence, assignment, state
6. ProgressSignal: evidence events, test status, review state, CI, heartbeat
7. WorkerSignals: composite of all above + worker_id + observed_at

### Tmux Surface (tmux.py)
- ~160 lines of regex patterns for TUI detection, prompt matching, blocker phrases
- PaneCapture dataclass for deterministic pane input
- XSM pane options: @xsm_role, @xsm_assignment, @xsm_assignment_epoch, @xsm_action, @xsm_worker_primed
- TUI family detection: Claude, Codex, Gemini, shell

### Subprocess Calls
1. tmux commands (capture-pane, send-keys, set-option, display-message)
2. xr repertoire CLI (run routine with JSON vars)
3. bd bead backend CLI (children, show)
4. git commands (branch, commit, status queries)

### Module-Level Mutable State
1. `_state_handlers` dict in wrangle.py (populated at import)
2. InterventionTracker._states dict (mutated per tick)
3. Previous pane_texts/progress_signals dicts in monitor.py streaming

### Time-Dependent Logic
- Heartbeat TTL: 180s freshness window
- Intervention cooldown: configurable reinvoke_cooldown_seconds
- Idle threshold: configurable idle_threshold_seconds
- Session timeout: configurable session_timeout_seconds
- Monitor scan interval: configurable scan_interval_seconds

## Test Coverage Summary

### What IS Well Tested
- State machines (lifecycle transitions, intervention ladder, worker states)
- Data persistence (SQLite serialization, YAML round-trips, recovery across restarts)
- Crash recovery (7-category drill: restart, epoch, census, quarantine, resume, gates, idempotency)
- Tmux command building (all command types validated)
- TUI classification (realistic Unicode fixtures, past-tense edge cases)
- Installation scripts (full bash integration tests)
- CLI structure (all commands exercised via CliRunner)
- Configuration loading (YAML parsing, validation, path resolution)

### What IS NOT Well Tested
- **Real tmux sessions**: All tmux tests use mocks or pre-captured fixtures. Zero live session testing.
- **Adversarial input**: No malformed pane text, corrupted state files, or malicious configs
- **Concurrent access**: Single-threaded by design; no multi-process contention tests
- **Performance**: No large backlog (1000+ items), large swarm (50+ agents), or throughput tests
- **State divergence**: No tests for tmux state changing between captures, git refs changing mid-flight
- **Feature interactions**: Hooks exist but never executed; QA gates exist but never called; repertoire routines never invoked
- **Daemon lifecycle**: No process spawning/reaping, signal handling, or log rotation tests

## Design Principles (from xsm-swarm-principles.md, design-approved)

### Core Coordination Invariants
1. Sole coordinator — one XSM instance per repo
2. Merge policy authority — XSM is final arbiter of merge readiness
3. Repo content as adversarial input — never trust pane text or worker declarations
4. Deterministic infrastructure — classification must be reproducible from signals

### Authority and State Invariants
- Ownership fencing via lease records and control epochs
- No credential storage — workers hold their own auth

### Lifecycle and Gate Invariants
- Work lifecycle state machine with explicit transitions
- Admission gates (pre-assignment artifacts)
- QA approval required before landing
- Landing queue serialization

### Recovery and Failure Invariants
- Agent lifecycle recovery (crash detection, state restoration)
- Split-brain detection and quarantine
- Idempotent recovery operations

### Quality Verification
- 5-layer QA model (static, automated, manual, external, approval)

### What XSM Is NOT (from design docs)
- NOT an orchestrator or task planner
- NOT an agent runtime
- NOT a build system
- Strictly a monitor, classifier, and intervention system

## Review Criteria

### PRODUCT REVIEW (P1-P7)
- **P1 Scope discipline**: Does every feature earn its complexity? Speculative controls/modes/abstractions that add weight without improving coordination?
- **P2 Deterministic operator trust**: Can an operator predict what XSM will do from inputs + state + policy?
- **P3 Intervention proportionality**: Proportionate, legible, reversible actions? Or escalate too fast / create noise?
- **P4 Human trust surface**: Audit logs, visualizations, CLI flows good enough for WHY understanding — especially under stress?
- **P5 Signal-to-noise**: Surface the few things that matter, or overwhelm?
- **P6 Manager stays in its lane**: Strictly managing containers and context, or agent-level logic leaking in?
- **P7 Failure containment posture**: Degrade safely when uncertain? Or aggressive remediation?

### TECHNICAL REVIEW (T1-T10)
- **T1 Determinism**: Same inputs + state = same output. Wall-clock deps, unordered collections, racey polling, ambient state.
- **T2 State model integrity**: SQLite transactions, WAL/locking, read-after-write, idempotency, crash recovery.
- **T3 Module boundary clarity**: Clean separation? Or broad mutable objects and policy leakage?
- **T4 Tmux surface resilience**: Pane parsing robustness against ANSI noise, partial output, zombie panes.
- **T5 Intervention safety**: Escalation thresholds, cooldowns, back-off, max limits. Cascade harm? Atomic recording?
- **T6 Audit coherence**: Replay prior run → same decisions? Full chain: observed → classified → policy → action → outcome?
- **T7 Test realism**: Invariants, replay, crash recovery, flaky tmux, adversarial output? Or fixture-driven happy-path?
- **T8 Security hardening**: Shell command construction, pane text injection, session targeting, secrets in audit/state.
- **T9 Complexity hotspots**: main.py 2947 lines — god objects? Mixed responsibilities?
- **T10 Design doc alignment**: Match xsm-swarm-principles.md? Sole coordinator, fencing epochs, deterministic-first, adversarial input.

### FAILURE MODES TO HUNT
1. Feedback loop ouroboros (intervention → error → intervention)
2. State/world divergence (SQLite vs tmux vs memory)
3. False certainty from weak signals
4. Escalation drift from stale state
5. Policy buried in incidental code
6. Happy-path overfitting in lifecycle model

### GRADING
Each criterion A-F with specific findings cited by file:line_number.
