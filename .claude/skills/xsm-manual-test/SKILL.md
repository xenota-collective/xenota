---
name: xsm-manual-test
description: Run the 5-step XSM manual test plan against the live xenota swarm. Tests monitor classification, active agent protection, targeted nudge, /clear sequence, and escalation.
---

# XSM Manual Test

Bead: xc-euar

## Overview

Run 5 tests in order against the live swarm to validate XSM's wrangle engine. Each test builds on the last. Do not skip tests — if one fails, stop and diagnose before continuing.

## Prerequisites

```bash
cd /Users/jv/gt/xenota/crew/horizon/xenon/packages/xsm
```

XSM must be installed in its venv:
```bash
.venv/bin/xsm --help    # should show CLI commands
```

Swarm config at `/Users/jv/gt/xenota/.xsm/swarm.yaml`. Strategy at `/Users/jv/gt/xenota/.xsm/strategies/observe.yaml`.

The feature branch `horizon/xc-g57d-xsm-intervention` must be checked out in xenon.

## Shared Variables

```bash
XSM=".venv/bin/xsm"
CONFIG="/Users/jv/gt/xenota/.xsm/swarm.yaml"
TMUX="/opt/homebrew/bin/tmux"
SOCKET="gt"
```

## Test 1: Monitor Classification (read-only)

**Goal**: Verify TUI detection correctly identifies agent types and states.

```bash
PATH="/opt/homebrew/bin:$PATH" $XSM monitor --config $CONFIG --once --json 2>&1 | python3 -m json.tool
```

**Check each agent in the output:**
- `state` should be `active` if the agent is mid-tool-call or thinking, `idle_prompt` if at a prompt
- Verify manually by capturing the pane and eyeballing:
  ```bash
  $TMUX -L $SOCKET capture-pane -p -t xc-crew-<name> | tail -10
  ```
- For each agent, does XSM's classification match what you see in the pane?

**Pass criteria**: All agents classified correctly. No agent marked `stalled` when they're actually at a TUI prompt (should be `idle_prompt`). No agent marked `idle_prompt` when they're actively working (should be `active`).

**Common failures**:
- Agent shows `stalled` but is at a Claude Code prompt → TUI detection missed the `-- INSERT --` mode line. Check if the pane content has a recognizable status bar.
- Agent shows `active` but is idle → the `✻ <verb>ing` regex matched past-tense text. Check the pane for stale activity indicators.

## Test 2: Active Agent Protection

**Goal**: Verify horizon (you) is never targeted while actively working.

First, ensure horizon is in the swarm config. If you trimmed it for testing, add it back:
```yaml
  - name: horizon
    driver: claude
    session: xc-crew-horizon
    context:
      assignment: "xc-euar: Manual test XSM wrangle on live swarm"
```

Run wrangle live (NOT dry-run) for 3 iterations while you are actively doing things in this session:

```bash
PATH="/opt/homebrew/bin:$PATH" $XSM wrangle --config $CONFIG --iterations 3 2>&1
```

**While it runs**, keep working — read files, run commands, anything that keeps the pane active.

**Check output**: horizon should NOT appear in any wrangle pass actions. If it does, the TUI detection is misclassifying your active session.

**Pass criteria**: Zero actions targeting horizon across all passes.

**If it fails**: Check what your pane looked like at capture time. The `· Doing…` or `✻ <verb>ing…` activity indicator may not have been visible. This is a TUI detection issue, not a wrangle logic issue.

## Test 3: Targeted Nudge on Idle Agent

**Goal**: Verify a nudge with assignment context actually appears in the agent's pane.

Pick an agent that is genuinely idle. Check first:
```bash
$TMUX -L $SOCKET capture-pane -p -t xc-crew-last | tail -5
```

If `last` is at a prompt (❯ visible, no activity indicator), proceed.

Ensure the config has context for last:
```yaml
  - name: last
    driver: claude
    session: xc-crew-last
    context:
      assignment: "xc-dw09.10.2.2: Code review for config/settings API"
```

Run a single live wrangle pass:
```bash
PATH="/opt/homebrew/bin:$PATH" $XSM wrangle --config $CONFIG --iterations 2 2>&1
```

**Check**: After pass 2, capture last's pane:
```bash
$TMUX -L $SOCKET capture-pane -p -t xc-crew-last | tail -10
```

The nudge text should be visible in the pane input area. It should reference "xc-dw09.10.2.2: Code review for config/settings API".

**Pass criteria**: The nudge text appears in the pane and references the assignment from context.

**If the nudge doesn't appear**: Check if `wait_for_idle_prompt` timed out (the actuator waits up to 30 attempts). The agent may not have been at an idle prompt when XSM tried to inject. Check the wrangle output for `ok: false`.

## Test 4: /clear + Instruction Sequence

**Goal**: Verify the full reset_and_assign flow — `/clear` fires as its own command, pane resets, then instruction appears.

**WARNING**: This sends `/clear` to a real agent session. Only target an agent that is genuinely idle with no uncommitted work. Check first:
```bash
$TMUX -L $SOCKET capture-pane -p -t xc-crew-last | tail -5
# Should show idle prompt, no active work
```

Create a temporary strategy with a short cooldown for faster ladder progression:
```bash
cat > /tmp/xsm-test-strategy.yaml << 'EOF'
name: test-fast
version: 1
formulas:
  default: implement
  available: [implement]
lifecycle:
  session_per_bead: false
  max_concurrent_agents: 10
  session_timeout: 60m
worker_contract:
  require_status_tuple: false
  idle_without_blocked: notify
detection:
  idle_threshold: 5s
  classify_states: [active, idle_prompt, stalled, stopped, crashed]
intervention:
  ladder:
    - nudge
    - diagnose_and_inject
    - escalate
  max_reinvokes_per_bead: 3
  reinvoke_cooldown: 5s
incidents:
  enabled: false
  repeated_reinvoke_threshold: 3
  cascade_block_depth: 2
  swarm_idle_threshold: 2
  throughput_window: 30m
assignment:
  ready_filter: "status=open"
  priority_order: true
  driver_preference:
    default: claude
EOF
```

Create a test config that targets ONLY last (to avoid hitting other agents):
```bash
cat > /tmp/xsm-test-config.yaml << 'EOF'
repo: /Users/jv/gt/xenota
strategy: /tmp/xsm-test-strategy.yaml

drivers:
  - claude

agents:
  - name: last
    driver: claude
    session: xc-crew-last
    context:
      assignment: "xc-dw09.10.2.2: Code review for config/settings API"

monitor:
  scan_interval: 5s
  log_path: /tmp/xsm-test-log
  leader_notification_path: /tmp/xsm-test-leader.jsonl
  tmux_socket: gt
EOF
```

Run 6 iterations (enough to walk past nudge to diagnose_and_inject):
```bash
PATH="/opt/homebrew/bin:$PATH" $XSM wrangle --config /tmp/xsm-test-config.yaml --iterations 6 2>&1
```

**Expected sequence**:
- Pass 1: no actions (baseline)
- Pass 2: nudge (first idle detection)
- Pass 3: no actions (5s cooldown)
- Pass 4: reset_and_assign → `/clear` then instruction (ladder advanced)
- Pass 5: no actions (cooldown)
- Pass 6: escalate (ladder exhausted) OR no actions

**After pass 4, immediately capture**:
```bash
$TMUX -L $SOCKET capture-pane -p -t xc-crew-last | tail -15
```

You should see evidence of `/clear` having been processed (the pane will look freshly cleared) and the standing-order instruction text.

**Pass criteria**:
1. `/clear` was sent as its own command (not concatenated with the instruction)
2. The pane shows the instruction text after the clear
3. The agent's context was not corrupted (it can still respond)

**If /clear doesn't work**: The actuator's `reset_session` calls `send_prompt_line` with "/clear" which waits for idle, prepares the prompt (Escape → i for Claude), sends "/clear" literally, then sends Enter. If the agent isn't at an idle prompt, the wait times out and reset_session returns False.

## Test 5: Escalation Output

**Goal**: Verify escalations write to the leader inbox JSONL.

Clear any existing test inbox:
```bash
rm -f /tmp/xsm-test-leader.jsonl
```

Either: run enough iterations with the fast strategy from Test 4 to exhaust the ladder (nudge → diagnose_and_inject → escalate), OR: kill a test tmux session so XSM sees `stopped`:

```bash
# Option A: exhaust the ladder (use Test 4 config, run more iterations)
PATH="/opt/homebrew/bin:$PATH" $XSM wrangle --config /tmp/xsm-test-config.yaml --iterations 8 2>&1

# Option B: create and kill a throwaway session
$TMUX -L $SOCKET new-session -d -s xsm-test-dead -c /tmp "sleep 999"
# Add to config, then kill it
$TMUX -L $SOCKET kill-session -t xsm-test-dead
# Run wrangle — should see "session stopped" escalation
```

**Check the inbox**:
```bash
cat /tmp/xsm-test-leader.jsonl | python3 -m json.tool
```

**Pass criteria**: At least one entry with `"type": "wrangle_escalation"` and a meaningful reason.

## Cleanup

After all tests:
```bash
rm -f /tmp/xsm-test-strategy.yaml /tmp/xsm-test-config.yaml /tmp/xsm-test-leader.jsonl /tmp/xsm-test-log
```

Restore the production swarm config if you modified it.

## Recording Results

Post results as a bead comment on xc-euar:
```bash
bd comment xc-euar "Test results:
- Test 1 (classification): PASS/FAIL — notes
- Test 2 (active protection): PASS/FAIL — notes
- Test 3 (targeted nudge): PASS/FAIL — notes
- Test 4 (/clear sequence): PASS/FAIL — notes
- Test 5 (escalation): PASS/FAIL — notes"
```

If all 5 pass, close the bead:
```bash
bd close xc-euar --reason="All 5 manual tests passed"
```
