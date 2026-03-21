# xc-ezz4: tmux send-keys Input Delivery Investigation

> **Scope**: Investigation record only. Not operational guidance. No code changes.

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

This manifests when sessions bypass the standard `AcceptStartupDialogs` call
(e.g., manually created disposable test lanes that skip the `gt` spawn path).

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

## Existing Mitigations

All standard spawn paths call `AcceptStartupDialogs` after session creation,
which polls for and dismisses trust/bypass dialogs before input is sent.

## Key Findings

1. **Not an alternate-screen issue.** Claude Code does NOT use tmux alternate
   screen (`#{alternate_on}` = 0). The TUI renders on the main screen buffer.

2. **Not a detached-session issue.** `send-keys` works correctly on detached
   Claude sessions that have passed the dialog phase.

3. **Not a general timing race.** Text sent before init completes lands in the
   buffer correctly. The failure is specifically dialog interception, not
   general timing.

4. **The `sendKeysLiteralWithRetry` function cannot detect dialog state.** It
   only retries on transient tmux errors (session gone, server down), not on
   application-level input rejection.

## Confirmed Mitigation

Manual and disposable test lanes must call `AcceptStartupDialogs` before sending
any input. All standard spawn paths already do this.

## Possible Follow-up

The nudge delivery path (`NudgeSession`) currently has no dialog pre-flight
check — it assumes the prompt is ready if `pane_in_mode` is 0, but a startup
dialog is not a tmux mode. Adding dialog detection or post-send delivery
verification to the nudge path would close this gap.

## Test Evidence

| Scenario | send-keys return | Text visible | Text delivered |
|----------|-----------------|-------------|----------------|
| Shell prompt | 0 | Yes | Yes |
| Claude idle prompt | 0 | Yes | Yes |
| Claude detached idle | 0 | Yes | Yes |
| Claude trust dialog | 0 | **No** | **No (consumed)** |
| Claude before init | 0 | Yes (after init) | Yes |
