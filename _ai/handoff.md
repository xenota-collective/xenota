## XSM Handoff

Date: 2026-04-12
Repo: `/Users/jv/projects/xenota`
Submodule commit checkpoint: `xenon@84689d9` (`Fix XSM worker recovery and invalid assignment handling`)

### What Was Fixed

- Removed dynamic worker bleed-through so XSM uses configured agents instead of every workmux worker.
- Disabled live provisioning in `.xsm-local/strategies/live-backlog.yaml` to stop `_pending_*` / `xsm-worker-*` junk workers.
- Added workmux-aware named-lane restart/reopen behavior for `restart_session`.
- Protected the wrangler from generic worker interventions.
- Reset startup intervention ladders on XSM start.
- Fixed Claude idle-prompt classification so live parked Claude panes do not get trapped forever in `launching`.
- Removed Claude status-bar dependence from live tmux matching code. Status bar remains in tests/fixtures but is not part of matcher logic.
- Fixed the leftover `CLAUDE_STATUSBAR_RE` crash path in partial-TUI detection.
- Declared `nucleus` as a real runtime dependency of `xsm` in `xenon/packages/xsm/pyproject.toml`.
- Missing bead IDs now normalize as invalid assignments in real repo contexts.
- Invalid assignments now report once per assignment key instead of escalating every pass forever.

### Tests That Passed

Targeted XSM suite passed after the fixes:

```bash
uv run pytest -q xenon/packages/xsm/tests/test_tui_classification.py xenon/packages/xsm/tests/test_monitor.py xenon/packages/xsm/tests/test_wrangle.py
```

Result:

```text
323 passed in 5.08s
```

### Live Manager State

Current live manager pane:

- tmux target: `xc:0.2`
- current live run id: `1441737362d3463786729534d7a9e617`

Current behavior from `xc:0.2`:

- there is old scrollback from a failed start with `ModuleNotFoundError: No module named 'nucleus'`
- after reinstalling `xsm`, the next `xsm wrangle --config .xsm-local/swarm-backlog.yaml` run starts successfully
- pass 1: `2 escalations`
- passes 2+ : `no actions`

This means the manager is now alive and stable, not crashing on every run.

### Current Worker State

Persisted swarm state from `.xsm-local/state/swarm-backlog.sqlite3` shows:

- `worker-claude-1`: `parked_unassigned`
- `worker-claude-2`: `parked_unassigned`

Reason on both:

- `assignment invalidated (missing); previous assignment is no longer active; worker is awaiting dispatch after invalidated assignment`

The invalidated stale assignments are:

- `worker-claude-1`: `xc-t4ks.1.3`
- `worker-claude-2`: `xc-nqat`

Tracker state confirms the anti-spam fix is active:

- `worker-claude-1`: `reinvoke_count = 1`, `ladder_position = 1`
- `worker-claude-2`: `reinvoke_count = 1`, `ladder_position = 1`

So XSM is no longer thrashing those lanes every pass. The repeated prompt spam visible in the Claude panes is old scrollback from before the fix.

### What Is Still Wrong

The named Claude worker lanes are now correctly demoted to `parked_unassigned`, but they are not being given fresh valid work. They sit idle after the one-time invalid-assignment escalation.

The system has moved from:

- bad: repeatedly injecting dead-ticket prompts forever

to:

- better but incomplete: correctly invalidating stale assignments, then doing nothing

### Why The Claudes Are Idle

The live static backlog file still contains stale worker backlog entries:

- `.xsm-local/swarm-backlog.yaml`
  - `xc-t4ks.1.3`
  - `xc-nqat`

But the real ready queue from `bd ready --json` contains different valid work such as:

- `xc-1dja`
- `xc-aw6e`
- `xc-tt94`

XSM is not currently auto-slinging fresh valid worker beads into named `parked_unassigned` worker lanes after invalidating the stale assignment.

### Next Fix

Implement automatic redispatch for named worker lanes:

- when a named worker lands in `parked_unassigned` after `assignment invalidated (missing)`
- XSM should clear the stale assignment context and immediately pick a fresh valid worker bead from the real ready pool
- it should not just sit idle waiting forever

The likely code path to inspect first is pool/backlog dispatch:

- `xenon/packages/xsm/src/xsm/monitor.py`
  - `_enrich_pool_assignments(...)`
  - `build_swarm_snapshot(...)`

Questions to resolve:

- why the live named worker lanes are not being repopulated from pool/ready work
- whether the static `.xsm-local/swarm-backlog.yaml` model is preventing selection of real ready beads
- whether named lanes need explicit post-invalid-assignment reassignment logic in wrangle rather than passive pool enrichment

### Files To Read First

- `xenon/packages/xsm/src/xsm/tmux.py`
- `xenon/packages/xsm/src/xsm/monitor.py`
- `xenon/packages/xsm/src/xsm/wrangle.py`
- `xenon/packages/xsm/src/xsm/intervention.py`
- `xenon/packages/xsm/src/xsm/strategy.py`
- `xenon/packages/xsm/pyproject.toml`
- `.xsm-local/swarm-backlog.yaml`
- `.xsm-local/strategies/live-backlog.yaml`

### Useful Commands

```bash
tmux capture-pane -pt xc:0.2 | tail -n 220
sqlite3 .xsm-local/state/swarm-backlog.sqlite3 'select updated_at, wrangle_count, agents_json, interventions_json from swarm_state where singleton=1;'
workmux capture worker-claude-1 --lines 120
workmux capture worker-claude-2 --lines 120
bd ready --json | head -c 12000
git -C xenon show --stat --oneline 84689d9
```

### Notes

- `_ai/handoff.md` is written as the short bootstrap document for a fresh Codex session.
- There is also an open bead for monitor/wrangle pane-target divergence:
  - `xc-1dja (align xsm monitor with wrangle live workmux pane resolution)`
