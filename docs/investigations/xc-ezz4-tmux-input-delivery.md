# xc-ezz4: tmux send-keys Input Delivery Investigation

## Problem

During live reset testing on disposable session `xc-crew-resettest-claude:0.0`,
`tmux send-keys -l` and Enter did not visibly deliver prompt text into the Claude
TUI even though the pane was present and ready.

## Root Cause

**Startup dialogs consume `send-keys` input silently.**

When Claude Code shows a startup dialog (workspace trust or bypass permissions
warning), `tmux send-keys -l` delivers text to the pane's terminal input
successfully (return code 0), but the dialog's input handler discards
non-navigation keystrokes. The text is consumed and permanently lost — it does
not appear in the input buffer after the dialog is dismissed.

### Reproduction Steps

1. Create a tmux session with Claude in a directory without pre-existing trust:
   ```bash
   tmux new-session -d -s test "claude"  # in untrusted dir
   ```

2. Wait for the "Quick safety check" trust dialog to appear (~3-5s).

3. Send text while dialog is showing:
   ```bash
   tmux send-keys -t test -l "hello"  # returns 0 but text is lost
   ```

4. Dismiss the dialog with Enter:
   ```bash
   tmux send-keys -t test Enter
   ```

5. Observe: Claude prompt is empty. "hello" was consumed by the dialog.

### What the disposable test lane did wrong

The `xc-crew-resettest-claude` session was created manually (not through the
standard `gt` spawn path), so it **did not call `AcceptStartupDialogs`** before
attempting to send input. The standard polecat/crew/daemon spawn paths all call
`AcceptStartupDialogs` after `WaitForCommand`, which handles this.

## Existing Mitigations

The gastown codebase already has comprehensive dialog handling:

- `AcceptStartupDialogs()` — polls for trust + bypass dialogs and dismisses them
- `AcceptWorkspaceTrustDialog()` — polls with 8s timeout, 500ms interval
- `AcceptBypassPermissionsWarning()` — polls for bypass dialog
- `DismissStartupDialogsBlind()` — blind sequence for remediation

All standard spawn paths (`polecat_spawn`, `crew/manager`, `daemon/lifecycle`,
`witness/manager`, `refinery/manager`, `deacon/manager`) correctly call
`AcceptStartupDialogs` after session creation.

## Key Findings

1. **Not an alternate-screen issue.** Claude Code does NOT use tmux alternate
   screen (`#{alternate_on}` = 0). The TUI renders on the main screen buffer.

2. **Not a detached-session issue.** `send-keys` works correctly on detached
   Claude sessions that have passed the dialog phase.

3. **Not a timing race (mostly).** Even text sent before Claude finishes
   initializing ends up in the input buffer correctly — unless a dialog
   intercepts it.

4. **The `sendKeysLiteralWithRetry` function cannot detect dialog state.** It
   only retries on transient tmux errors (session gone, server down), not on
   application-level input rejection.

## Recommendations

1. **For manual/disposable test lanes**: Always call `AcceptStartupDialogs` (or
   `DismissStartupDialogsBlind`) before sending any input. Document this in
   testing runbooks.

2. **For `gt nudge` robustness**: Consider adding dialog detection to the nudge
   delivery path. Currently, nudge assumes the prompt is ready if `pane_in_mode`
   is 0, but a startup dialog is not a tmux mode — it's an application state.

3. **For the NudgeSession function**: Add a pre-flight check that captures the
   pane and looks for dialog indicators before sending literal text. If a dialog
   is detected, call `AcceptStartupDialogs` first.

## Test Evidence

| Scenario | send-keys return | Text visible | Text delivered |
|----------|-----------------|-------------|----------------|
| Shell prompt | 0 | Yes | Yes |
| Claude idle prompt | 0 | Yes | Yes |
| Claude detached idle | 0 | Yes | Yes |
| Claude trust dialog | 0 | **No** | **No (consumed)** |
| Claude before init | 0 | Yes (after init) | Yes |
