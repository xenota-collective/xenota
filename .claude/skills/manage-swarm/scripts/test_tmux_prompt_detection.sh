#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"

assert_ready() {
  local label="$1"
  local payload="$2"

  if ! tmux_pane_ready_for_input "$payload"; then
    echo "expected ready: $label" >&2
    exit 1
  fi
}

assert_not_ready() {
  local label="$1"
  local payload="$2"

  if tmux_pane_ready_for_input "$payload"; then
    echo "expected not ready: $label" >&2
    exit 1
  fi
}

assert_agent_ui() {
  local label="$1"
  local payload="$2"

  if ! tmux_pane_looks_like_agent_ui "$payload"; then
    echo "expected agent ui: $label" >&2
    exit 1
  fi
}

assert_not_agent_ui() {
  local label="$1"
  local payload="$2"

  if tmux_pane_looks_like_agent_ui "$payload"; then
    echo "expected non-agent ui: $label" >&2
    exit 1
  fi
}

codex_ready_payload="$(cat <<'EOF'
Token usage: total=49,069 input=45,549 (+ 192,000 cached) output=3,520 (reasoning 1,500)
To continue this session, run codex resume 019d0e99-c6d5-7d11-9927-4131ed65ee63

╭──────────────────────────────────────────────╮
│ >_ OpenAI Codex (v0.116.0)                   │
│                                              │
│ model:     gpt-5.4 medium   /model to change │
│ directory: ~/gt/xenota/crew/earthshot        │
╰──────────────────────────────────────────────╯

  Tip: New Use /fast to enable our fastest inference at 2X plan usage.

› Improve documentation in @filename

  gpt-5.4 medium · 91% left · ~/gt/xenota/crew/earthshot
EOF
)"

claude_ready_payload="$(cat <<'EOF'
Some prior output

❯
EOF
)"

shell_ready_payload="$(cat <<'EOF'
last command output
jv@host ~/gt/xenota/crew/earthshot %
EOF
)"

# oh-my-zsh robbyrussell prompt — the bare "%" trailing-char regex does not
# match this style and the only stable marker is the leading ➜ glyph. xc-fqskk:
# restart helpers stalled because tmux_wait_for_idle_prompt did not recognize
# this layout and refused to advance.
zsh_arrow_ready_payload="$(cat <<'EOF'
last command output
➜  worktrees git:(claude/xc-fqskk-restart-helpers) ✗
EOF
)"

# Same prompt style after a worktree closeout where the supervisor lane lands
# in a clean-but-named git working tree. The supervisor pane reported by the
# bead lives inside <repo>/.worktrees/supervisor and shows this exact form.
zsh_arrow_supervisor_payload="$(cat <<'EOF'
[detached HEAD a1b2c3d] xc-2q593: refresh xenon pointer after merge

➜  supervisor git:(main)
EOF
)"

busy_payload="$(cat <<'EOF'
Working on it now

• Working (33s • esc to interrupt)

  gpt-5.4 medium · 91% left · ~/gt/xenota/crew/earthshot
EOF
)"

gemini_ready_payload="$(cat <<'EOF'
✦ Task complete.
? for shortcuts
────────────────────────────────────────────────────────────────────────────────────────────────────────────
 YOLO Ctrl+Y
────────────────────────────────────────────────────────────────────────────────────────────────────────────
 *   Type your message or @path/to/file
────────────────────────────────────────────────────────────────────────────────────────────────────────────
 workspace (/directory)                                       branch
 ~/gt/xenota/crew/horizon                                     horizon/xc-st1n.3-dynamic-tool-registration
EOF
)"

rejected_clear_payload="$(cat <<'EOF'
/clear

What should Claude do instead?
EOF
)"

gemini_shell_mode_payload="$(cat <<'EOF'
  ▝▜▄     Gemini CLI v0.34.0
────────────────────────────────────────────────────────────────────────────────────────────────────────────
 YOLO Ctrl+Y
────────────────────────────────────────────────────────────────────────────────────────────────────────────
 ! Shell awaiting input (Tab to focus) ? for shortcuts
────────────────────────────────────────────────────────────────────────────────────────────────────────────
 >   Type your message or @path/to/file
 workspace (/directory)                                       branch
 ~/gt/xenota/crew/horizon                                     horizon/xc-st1n.3-dynamic-tool-registration
EOF
)"

assert_ready "codex ui prompt" "$codex_ready_payload"
assert_ready "claude prompt" "$claude_ready_payload"
assert_ready "shell prompt" "$shell_ready_payload"
assert_ready "gemini prompt" "$gemini_ready_payload"
assert_ready "zsh arrow prompt with branch and dirty marker" "$zsh_arrow_ready_payload"
assert_ready "zsh arrow prompt after worktree closeout" "$zsh_arrow_supervisor_payload"
assert_not_ready "busy codex footer without prompt" "$busy_payload"
assert_not_ready "rejected clear message" "$rejected_clear_payload"
assert_not_ready "gemini shell awaiting input" "$gemini_shell_mode_payload"
assert_agent_ui "codex ui history" "$codex_ready_payload"
assert_agent_ui "gemini ui history" "$gemini_ready_payload"
assert_not_agent_ui "shell history" "$shell_ready_payload"

if ! tmux_pane_has_live_activity "$gemini_shell_mode_payload"; then
  echo "expected shell-awaiting-input to count as live activity" >&2
  exit 1
fi

echo "tmux prompt detection checks passed"
