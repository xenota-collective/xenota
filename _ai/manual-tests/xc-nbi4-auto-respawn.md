# Manual Test Plan: xc-nbi4 XSM auto-respawn declared workers

**Bead:** xc-nbi4 (xsm: auto-respawn stopped worker tmux windows)
**xenon PR:** https://github.com/xenota-collective/xenon/pull/279
**Date:** 2026-04-23

## Feature summary

When a configured agent's tmux window disappears (killed, crashed, never opened after a fresh swarm init), the monitor patrol now elevates it to `RESPAWN_NEEDED` **only** if the agent entry carries `auto_respawn: true`. The executor then calls `provision_worker` (which in turn runs `workmux add`) to recreate the worktree + tmux window. A single `wrangle_escalation` notification with `state=respawned` is appended to `.xsm-local/leader-backlog.jsonl` so the operator can see what happened.

The flag is opt-in per agent. Agents without `auto_respawn: true` keep the prior behaviour (stopped lanes stay stopped until a human restarts them).

## Prerequisites

- [ ] Repo checkout at xenon submodule `xsm/xc-nbi4` (HEAD `610557e`) or later `main` after merge
- [ ] `packages/xsm/.venv` populated (`cd xenon/packages/xsm && uv sync`)
- [ ] `workmux` CLI available on PATH
- [ ] A disposable swarm YAML under `~/.xenons/xc-nbi4/` with two agents — one with `auto_respawn: true`, one without — pointed at the current xenota worktree

## Test xenon / config setup

Create a scratch config in a disposable location (never under `xenon/nucleus/.tmp/`):

```bash
mkdir -p ~/.xenons/xc-nbi4
cat > ~/.xenons/xc-nbi4/swarm.yaml <<'YAML'
session: xc-nbi4-test
agents:
  - name: respawn-yes
    driver: claude
    session: xc-nbi4-test
    auto_respawn: true
    capture: { enabled: false }
  - name: respawn-no
    driver: claude
    session: xc-nbi4-test
    auto_respawn: false
    capture: { enabled: false }
YAML
```

## AR-01: Config parses `auto_respawn` flag

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1 | `cd xenon/packages/xsm && .venv/bin/python -m pytest tests/test_config.py::test_load_config_parses_auto_respawn_flag -v` | Test PASSED | |
| 2 | In a Python REPL: `from xsm.config import load_config; cfg = load_config('~/.xenons/xc-nbi4/swarm.yaml')` | `cfg.agents[0].auto_respawn is True`, `cfg.agents[1].auto_respawn is False` | |

## AR-02: Monitor elevates stopped flagged agent to RESPAWN_NEEDED

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1 | Ensure the swarm's tmux session exists but neither agent window is live: `tmux -L gt new-session -d -s xc-nbi4-test` | Session exists, no agent windows | |
| 2 | Run the monitor snapshot: `.venv/bin/xsm monitor --config ~/.xenons/xc-nbi4/swarm.yaml --json` | `respawn-yes` shows `state=respawn_needed`; `respawn-no` shows `state=stopped` (or `missing`) — not elevated | |
| 3 | Verify evidence/reason on `respawn-yes` snapshot | Reason string includes "auto_respawn enabled" | |

## AR-03: Executor provisions via workmux when flag is on

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1 | Run wrangle once: `.venv/bin/xsm wrangle --config ~/.xenons/xc-nbi4/swarm.yaml --once --json` | Output shows a restart action for `respawn-yes` with `restarted_via=workmux_provision` | |
| 2 | `tmux -L gt list-windows -t xc-nbi4-test` | Window named `respawn-yes` now exists with agent command | |
| 3 | Rerun monitor `--json` | `respawn-yes` no longer in `respawn_needed`/`stopped` — running or idle | |

## AR-04: Executor refuses to provision when flag is off

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1 | Keep `respawn-no` window absent. Run wrangle once again | No restart action fires for `respawn-no`; decision includes `workmux_restart_failed` or equivalent "configured worktree handle not found" text | |
| 2 | `tmux -L gt list-windows -t xc-nbi4-test` | No `respawn-no` window created | |
| 3 | State in SQLite snapshot: `respawn-no` remains in `stopped`/`missing` state | Confirmed | |

## AR-05: Leader-backlog gets exactly one respawn notification per event

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1 | `tail -5 .xsm-local/leader-backlog.jsonl` after AR-03 | Last entry: `{"type":"wrangle_escalation","agent":"respawn-yes","state":"respawned","reason":"auto-respawned worker tmux window for respawn-yes", ...}` | |
| 2 | Rerun wrangle without killing the window again | No new `state=respawned` entry is appended (agent now healthy, no re-fire) | |
| 3 | Kill the `respawn-yes` window (`tmux -L gt kill-window -t xc-nbi4-test:respawn-yes`), rerun wrangle | One additional `state=respawned` entry; workmux creates the window again | |

## AR-06: Regression — resolved handle ≠ action.agent path (gemini review fix)

Covers the fix in `610557e`: when the workmux handle resolved for the agent differs from `action.agent` (e.g. session-qualified handle like `xc:respawn-yes`), `provision_worker` must receive the resolved handle, not the agent name, so the next monitor scan does not classify the agent as missing and loop forever.

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1 | `.venv/bin/python -m pytest tests/test_executor.py::test_restart_lane_auto_respawns_declared_agent_when_flagged -v` | Test PASSED | |
| 2 | Inspect the test body — it uses `xc:lane-handle-1` as expected handle, distinct from `action.agent`, and asserts `provision_worker` was called with `handle="lane-handle-1"` and `branch_name="lane-handle-1"` | Assertion present | |
| 3 | (Optional live) Configure a worktree whose workmux handle includes a session prefix, kill it, run wrangle twice | Second wrangle sees the agent healthy, not re-classified as missing | |

## Cleanup

```bash
tmux -L gt kill-session -t xc-nbi4-test 2>/dev/null || true
rm -rf ~/.xenons/xc-nbi4
# If workmux provisioned test worktrees, remove them:
workmux list
workmux remove respawn-yes 2>/dev/null || true
```

## Pass criteria (summary)

- AR-01 through AR-06 all green
- No stray `.xsm-local/leader-backlog.jsonl` entries beyond the one-per-respawn contract
- No runaway re-provision loop observed across repeated wrangles
