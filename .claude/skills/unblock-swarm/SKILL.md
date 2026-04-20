---
name: unblock-swarm
description: Diagnose and restart a stalled XSM swarm. Use when the operator says the swarm is blocked, a mix of workers are idle/dormant while others work, supervisor is dormant, or xsm appears alive but nothing is progressing. Walks through the correct escalation order: xsm daemon health → supervisor patrol → per-worker triage → blocker resolution.
---

# Unblock Swarm

Use after `review-swarm` confirms the swarm is not progressing. This skill mutates state: it may restart xsm, send keys to panes, merge approved PRs, or reassign work. Escalate to the operator before any action that is irreversible (force-pushes, merges of PRs the operator has not approved, deletes).

Hard rule: diagnose *before* intervening. A wrong intervention (e.g. `/clear`-ing a worker that is legitimately waiting on an approval) destroys real progress.

## Step 1: Confirm xsm is alive and wrangling

```bash
pgrep -af "xsm wrangle"
/opt/homebrew/bin/tmux capture-pane -pt xc:0.2 -S -60 | tail -30
```

Classify:
- **Dead**: no `xsm wrangle` process, pane tail is a Python traceback or shell prompt. Fix the traceback (if any) and restart:
  ```bash
  /Users/jv/projects/xenota/.claude/skills/manage-swarm/scripts/restart_local_xsm.sh xc:0.2
  ```
  If the traceback is a code bug, fix the code in `xenon/packages/xsm/src/xsm/`, run `.venv/bin/python -m pytest tests/ -x -q`, then restart.
- **Alive but no new events**: process exists but the pane has been silent for >60s. Check `/Users/jv/projects/xenota/.xsm-local/log/swarm-backlog/wrangle-runs/<latest>/events.jsonl` line count — if not growing, xsm is hung; kill and restart.
- **Alive and wrangling**: pane is emitting `wrangle run … pass N` lines and events.jsonl is growing. Move to Step 2.

Fix xsm first. Without a live daemon, no nudges go out and every worker looks stuck regardless of its real state.

## Step 2: Read every pane — identify what each lane actually is

Do not guess. Each window may have one pane or several (workmux sidebar, helper shells, etc.), and pane indices are not stable — **do not hardcode `.1`**. Discover the agent pane per window by `pane_current_command`:

```bash
for win in $(/opt/homebrew/bin/tmux list-windows -t xc -F '#{window_name}'); do
  /opt/homebrew/bin/tmux list-panes -t "xc:$win" -F "xc:$win.#{pane_index} #{pane_current_command}"
done
```

Map commands to agent type:
- `node` → codex TUI (the agent)
- `claude` / `2.1.x` (or whatever Claude's process name is on this host) → Claude Code TUI (the agent)
- `workmux` → sidebar/dashboard, **skip**
- `zsh` / `bash` / `fish` → shell, either a helper pane or a dead agent (see Step 6 to disambiguate)

For a window with exactly one agent-typed pane, that's the target. For a window with none, the agent has died — mark it `shell` and move on. Never capture a pane whose command is `workmux` and report on its contents as if it were the agent.

Capture the discovered agent panes:
```bash
/opt/homebrew/bin/tmux capture-pane -pt "$target" -S -60 | tail -40
```

Classify each lane into exactly one bucket:

- **working**: live tool output, "Waiting for background terminal (Nm Ns)", MCP booting, active cogitation. **Do not touch.**
- **waiting-on-human**: pane shows an explicit decision request ("Should I merge…", "Human approval needed", "approve/deny?"). This is healthy blocking — operator action required, not xsm action.
- **parked-handoff**: completed a slice (PR open, handoff summary posted) and returned to idle prompt. xsm should reassign; if xsm hasn't, see Step 3.
- **dormant**: idle codex/claude prompt with no recent motion and no explicit blocker. Needs a nudge.
- **shell**: agent process has died, pane is at zsh. Needs relaunch.
- **stuck-in-tui**: pane shows modal/editor/permission prompt the agent can't dismiss. Needs reset.

Write this list down before acting. Don't skip it.

## Step 3: Supervisor dormant → check patrol interval and xsm routing

Supervisor is patrolled by xsm on an interval (see `strategies/live-backlog.yaml`, `patrol.interval`). If supervisor shows as dormant:

1. Confirm the strategy includes `supervisor` in `patrol.roles` and has a `role_messages.supervisor` entry.
2. Grep the current wrangle run events for supervisor patrol calls:
   ```bash
   latest=$(ls -t /Users/jv/projects/xenota/.xsm-local/log/swarm-backlog/wrangle-runs/ | head -1)
   grep -c '"agent": "main"' /Users/jv/projects/xenota/.xsm-local/log/swarm-backlog/wrangle-runs/$latest/events.jsonl
   ```
3. If count is 0 after >5 minutes of xsm uptime, patrol is not firing. Check that the supervisor's session target (`xc:supervisor`) matches the actual tmux target and that the agent is declared in `.xsm-local/swarm-backlog.yaml` under `agents:`.
4. If patrol did fire but the supervisor codex ignored it, the prompt may be failing inside the supervisor's worktree (path problems, missing venv). Capture the pane and look for error lines.
5. Only nudge the supervisor manually as a last resort — the patrol is the primary channel.

## Step 4: Worker dormant → let xsm handle it, don't race it

If xsm is alive and in a healthy wrangle loop, it will reset/reassign dormant workers itself. Give it one full pass (watch events.jsonl grow by at least 20 lines) before intervening manually.

If xsm is already trying and failing (same agent+bead `reset_and_assign`'d 3+ times in the last 100 events), xsm is in an unproductive loop. Options:
- The bead's definition may be unimplementable as-stated → close the bead or rewrite it in `bd`.
- The worker may have stale context that rejects `/clear` → manually reset:
  ```bash
  /Users/jv/projects/xenota/.claude/skills/manage-swarm/scripts/clear_and_assign.sh <name> '<new assignment>'
  ```
- Consider whether the wrangler is stuck on a bead with no valid dispatch (e.g. waiting on a PR merge). In that case, resolve the upstream blocker first.

## Step 5: Workers waiting-on-human → resolve the gate, then clear the lane

If a worker pane shows "Should I merge…" or is parked at a handoff-ready PR, the operator is the blocker. For each waiting-on-human lane:

1. Open the PR, read the changes, confirm CI is green.
2. If approved: merge through the correct landing path (never bypass `land-submodule-stack` for submodule stacks). **Self-merge rail**: do NOT merge a PR whose author flavor matches your own driver (you are claude → do not merge worker-claude PRs without operator approval; a codex supervisor must not merge worker-codex PRs).
3. If rejected: post review comments and nudge the worker back onto fixes.
4. After the gate is resolved, the lane is still parked on old context. Clear and reassign:
   ```bash
   /Users/jv/projects/xenota/.claude/skills/manage-swarm/scripts/clear_and_assign.sh <name> '<next assignment>'
   ```

Do not leave a cleared lane without a fresh assignment — xsm will re-assign stale context if the lease isn't released.

## Step 6: Shell / dead agent → relaunch

If a pane's `pane_current_command` is `zsh`/`bash` instead of `node`/`claude`, the agent crashed. Relaunch it by hand:

- **Codex lanes**: `codex --yolo` from inside the worker's worktree.
- **Claude lanes**: `claude` (or the configured launcher) from inside the worker's worktree.

Verify relaunch with `pane_current_command` changing to `node` or `claude`, not with scrollback alone.

## Step 7: Verify motion, then stop

After interventions, re-capture every touched pane within 60 seconds:

```bash
sleep 30
/opt/homebrew/bin/tmux capture-pane -pt xc:<target> -S -20 | tail -15
```

Motion = new lines since intervention, or `pane_current_command` advancing to a tool call. Scrollback is not proof.

End the unblock pass with a one-line summary:

```
unblock: xsm <restarted|healthy>, supervisor <ok|nudged>, workers unblocked: <list>, PRs merged: <list or none>, still-waiting: <list or none>
```

## What NOT to do

- Do not mass-`/clear` every worker because the swarm "looks stuck". Working or waiting-on-human lanes must be left alone.
- Do not restart xsm while a traceback is unfixed — it will crash again on the same action.
- Do not merge a PR whose author flavor matches your driver without explicit operator approval.
- Do not kill codex/claude sessions; use `/clear` via the helper so the session reuses its auth and MCPs.
- Do not skip Step 2. Intervening on an unclassified lane is how progress gets destroyed.
- Do not treat a delivered nudge as proof of motion. Re-capture the pane.
