# Manual Test Plan: xc-7dgr.12 XSM Recovery Drill

**Bead:** xc-7dgr.12 (Add XSM recovery drill and integration test harness)
**Date:** 2026-04-04
**Prerequisite:** XSM configured with at least 2 agents in a live tmux swarm.

---

## Prerequisites

- [ ] XSM installed and `xsm` CLI available (`uv run xsm --help`)
- [ ] A swarm config with 2+ agents (e.g., `~/.xsm/swarm.yaml`)
- [ ] SQLite state DB path known (from config `monitor.state_db_path`)
- [ ] tmux running with configured agent sessions
- [ ] Integration test suite passing: `uv run pytest tests/test_recovery_drill.py`

---

## RD-01: Automated Integration Tests Pass

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1 | `cd xenon/packages/xsm && uv run pytest tests/test_recovery_drill.py -v` | All 27 tests pass | |
| 2 | Review test names cover: restart recovery, epoch rotation, census mismatch, quarantine, safe resume, lifecycle integrity, end-to-end | All 7 drill categories represented | |

**Pass criteria:** All tests green. No skipped tests.

---

## RD-02: Restart Recovery (State Persistence)

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1 | Start XSM wrangle with `--once`: `xsm wrangle --config swarm.yaml --once --json` | JSON output with wrangle decisions; state.db updated | |
| 2 | Inspect state.db: `sqlite3 state.db "SELECT wrangle_count, agents_json, interventions_json FROM swarm_state"` | wrangle_count > 0, agents and interventions populated | |
| 3 | Run wrangle again with `--once` | wrangle_count incremented; interventions carry forward from previous pass | |
| 4 | Kill XSM (Ctrl+C or SIGTERM) mid-wrangle, then re-run with `--once` | State restored correctly: wrangle_count continues, intervention ladder positions preserved | |

**Pass criteria:** Intervention state (ladder position, reinvoke count, assignment keys) survives process restart.

---

## RD-03: Control Epoch Rotation

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1 | Note current epoch: `sqlite3 state.db "SELECT value FROM schema_meta WHERE key='control_epoch'"` | Returns a hex string | |
| 2 | Run `xsm wrangle --config swarm.yaml --once` (non-dry-run) | Epoch rotates to a new value | |
| 3 | Check epoch again | Different hex string than step 1 | |
| 4 | Run `xsm wrangle --config swarm.yaml --once --dry-run` | Epoch does NOT change (dry-run preserves) | |

**Pass criteria:** Each non-dry-run wrangle start rotates the epoch. Dry-run preserves it.

---

## RD-04: Live Census vs SQLite Mismatch

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1 | With 2 agents running, run wrangle `--once` and confirm both appear in output | Both agents listed with observed state | |
| 2 | Kill one agent's tmux session: `tmux kill-session -t <agent-session>` | Session dies | |
| 3 | Run wrangle `--once` again | Surviving agent processed normally; killed agent absent from snapshot | |
| 4 | Check active leases: `sqlite3 state.db "SELECT agent_name, lease_state FROM leases WHERE lease_state='active'"` | Killed agent's lease still active (wrangle alone doesn't quarantine) | |

**Pass criteria:** Census accurately reflects only live tmux sessions. Dead sessions are absent.

---

## RD-05: Quarantine via Lease Release

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1 | With an agent's lease active but session dead (from RD-04), manually release: `sqlite3 state.db "UPDATE leases SET lease_state='released', release_reason='quarantine: manual drill' WHERE agent_name='<dead-agent>' AND lease_state='active'"` | Row updated | |
| 2 | Verify lease released: `sqlite3 state.db "SELECT agent_name, lease_state, release_reason FROM leases WHERE agent_name='<dead-agent>' ORDER BY id DESC LIMIT 1"` | lease_state=released, reason=quarantine | |
| 3 | Attempt to acquire a new lease for the same bead with a different agent (via XSM assignment) | New lease acquired without conflict | |

**Pass criteria:** Released lease unblocks bead for reassignment.

---

## RD-06: Safe Resume After Crash

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1 | Set up: 2 agents working, wrangle running, both at various ladder positions | Both agents tracked in state.db | |
| 2 | Kill XSM process (SIGKILL to simulate crash) | XSM dies immediately | |
| 3 | Restart XSM wrangle | New control epoch issued; previous state restored | |
| 4 | Verify: agents that are still alive in tmux continue being wrangled | Wrangle decisions target live agents only | |
| 5 | Verify: ladder positions preserved | Agent at step 1 before crash is still at step 1 after | |

**Pass criteria:** XSM resumes at the exact intervention state it had before crash for all surviving agents.

---

## RD-07: Lifecycle Gate Enforcement After Restart

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1 | Progress a bead to ASSIGNED state via CLI | lifecycle_state = assigned in bead_lifecycle table | |
| 2 | Kill and restart XSM | State persists in SQLite | |
| 3 | Attempt to skip to ACTIVE (bypassing ISOLATED) | Rejected: LifecycleTransitionError | |
| 4 | Progress through ISOLATED, then to ACTIVE with proper alignment artifact | Succeeds | |

**Pass criteria:** Lifecycle state machine constraints cannot be bypassed by restart.

---

## RD-08: Idempotent Recovery

| Step | Action | Expected | Pass/Fail |
|------|--------|----------|-----------|
| 1 | With one agent crashed and quarantined, run recovery procedure | One agent remains active | |
| 2 | Run the exact same recovery procedure again | Same result: same active agent, no errors, no duplicate releases | |

**Pass criteria:** Recovery is safe to run multiple times. No side effects on re-run.

---

## Known Failure Set (from principles doc)

These are the specific scenarios the principles document requires drill coverage for:

| Scenario | Covered By | Status |
|----------|-----------|--------|
| Crash during ACTIVE | RD-06, integration test `test_crash_during_active_full_recovery` | |
| Split-brain on restart | RD-04, integration test `test_split_brain_both_directions` | |
| Budget exhaustion mid-bead | Integration test `test_exhaustion_flag_persists_across_restart` | |
| Epoch violation after restart | RD-03, integration tests `TestControlEpochRecovery` | |

---

## Summary

| Drill | Description | Pass/Fail |
|-------|-------------|-----------|
| RD-01 | Automated integration tests | |
| RD-02 | Restart recovery | |
| RD-03 | Epoch rotation | |
| RD-04 | Census mismatch detection | |
| RD-05 | Quarantine via lease release | |
| RD-06 | Safe resume after crash | |
| RD-07 | Lifecycle gate enforcement | |
| RD-08 | Idempotent recovery | |

**Overall verdict:** ______ (PASS requires all 8 drills green)
