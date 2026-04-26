#!/usr/bin/env bash
set -euo pipefail

tmux_bin="${TMUX_BIN:-/opt/homebrew/bin/tmux}"
tmux_cmd=("$tmux_bin")
default_shell="${SHELL:-/bin/zsh} -l"

tmux_pane_title() {
  local target="$1"
  "${tmux_cmd[@]}" display-message -p -t "$target" '#{pane_title}'
}

tmux_pane_current_command() {
  local target="$1"
  "${tmux_cmd[@]}" display-message -p -t "$target" '#{pane_current_command}'
}

tmux_pane_start_command() {
  local target="$1"
  "${tmux_cmd[@]}" display-message -p -t "$target" '#{pane_start_command}'
}

tmux_recent_pane_text() {
  local target="$1"
  "${tmux_cmd[@]}" capture-pane -p -t "$target"
}

tmux_pane_ready_for_input() {
  local recent="$1"
  local bottom last_line

  if grep -Fq 'What should Claude do instead?' <<<"$recent"; then
    return 1
  fi

  bottom="$(
    awk 'NF { print }' <<<"$recent" | tail -n 12
  )"
  last_line="$(tail -n 1 <<<"$bottom")"

  if grep -q '^›' <<<"$bottom"; then
    return 0
  fi

  if grep -q '^❯' <<<"$bottom"; then
    return 0
  fi

  if grep -Fq 'Type your message' <<<"$bottom"; then
    return 0
  fi

  if [[ "$last_line" == "❯"* ]] || [[ "$last_line" =~ [\$#%][[:space:]]*$ ]]; then
    return 0
  fi

  return 1
}

tmux_pane_has_live_activity() {
  local recent="$1"
  local bottom

  bottom="$(
    awk 'NF { print }' <<<"$recent" | tail -n 20
  )"

  if grep -Eq 'Working \(|Generating|Zesting|Sautéing|Thinking|Running…|Waiting…|Spinning…|esc to interrupt|Press up to edit queued messages|Interrupted · What should Claude do instead\?|Close dialogs and suggestions|[✳✻✶⏺] ' <<<"$bottom"; then
    return 0
  fi

  return 1
}

tmux_pane_looks_like_agent_ui() {
  local recent="$1"

  if grep -Fq 'OpenAI Codex' <<<"$recent"; then
    return 0
  fi

  if grep -Fq 'Claude Code' <<<"$recent"; then
    return 0
  fi

  if grep -Fq 'Type your message' <<<"$recent"; then
    return 0
  fi

  if grep -q '^›' <<<"$recent"; then
    return 0
  fi

  return 1
}

tmux_pane_is_sidebar() {
  local target="$1"
  local current_command width

  current_command="$(tmux_pane_current_command "$target")"
  if [[ "$current_command" == "workmux" ]]; then
    return 0
  fi

  width="$( "${tmux_cmd[@]}" display-message -p -t "$target" '#{pane_width}' )"
  if [[ "$width" -lt 40 ]]; then
    # Sidebars are typically narrow
    return 0
  fi

  return 1
}

tmux_pane_family() {
  local target="$1"
  local pane_title current_command start_command recent

  if tmux_pane_is_sidebar "$target"; then
    printf 'sidebar\n'
    return 0
  fi

  pane_title="$(tmux_pane_title "$target")"
  current_command="$(tmux_pane_current_command "$target")"
  start_command="$(tmux_pane_start_command "$target")"
  recent="$(tmux_recent_pane_text "$target")"

  if [[ "$pane_title" == *"Claude Code"* ]] || [[ "$start_command" == *"/claude"* ]] || grep -Fq 'Claude Code' <<<"$recent"; then
    printf 'claude\n'
    return 0
  fi

  if [[ "$start_command" == *"gemini"* ]] || grep -Fq 'Type your message' <<<"$recent" || grep -Fq '? for shortcuts' <<<"$recent"; then
    printf 'gemini\n'
    return 0
  fi

  if [[ "$start_command" == *"codex"* ]] || grep -Fq 'OpenAI Codex' <<<"$recent"; then
    printf 'codex\n'
    return 0
  fi

  if [[ "$current_command" == "zsh" || "$current_command" == "bash" || "$current_command" == "fish" || "$current_command" == "sh" ]]; then
    printf 'shell\n'
    return 0
  fi

  if tmux_pane_looks_like_agent_ui "$recent"; then
    printf 'agent\n'
    return 0
  fi

  printf 'shell\n'
}

tmux_clear_reset_command() {
  local family="$1"

  case "$family" in
    claude|gemini|codex|agent)
      printf '/clear\n'
      ;;
    *)
      return 1
      ;;
  esac
}

tmux_send_raw_keys() {
  local target="$1"
  shift
  "${tmux_cmd[@]}" send-keys -t "$target" "$@"
}

tmux_send_literal_text() {
  local target="$1"
  local text="$2"

  if [[ "$text" == *$'\n'* ]]; then
    "${tmux_cmd[@]}" set-buffer -- "$text"
    "${tmux_cmd[@]}" paste-buffer -d -t "$target"
    return 0
  fi

  "${tmux_cmd[@]}" send-keys -t "$target" -l "$text"
}

tmux_prepare_prompt_for_input() {
  local target="$1"
  local family

  family="$(tmux_pane_family "$target")"

  case "$family" in
    shell)
      tmux_send_raw_keys "$target" Escape
      sleep 0.2
      tmux_send_raw_keys "$target" C-c
      sleep 0.2
      tmux_send_raw_keys "$target" C-u
      ;;
    claude)
      tmux_send_raw_keys "$target" Escape
      sleep 0.2
      tmux_send_raw_keys "$target" i
      ;;
    gemini)
      tmux_send_raw_keys "$target" Escape
      sleep 0.2
      tmux_send_raw_keys "$target" Escape
      sleep 0.2
      tmux_send_raw_keys "$target" C-u
      ;;
    codex|agent)
      tmux_send_raw_keys "$target" Escape
      sleep 0.2
      tmux_send_raw_keys "$target" C-u
      ;;
    *)
      tmux_send_raw_keys "$target" Escape
      sleep 0.2
      tmux_send_raw_keys "$target" C-u
      ;;
  esac
}

tmux_recent_has_command_rejection() {
  local recent="$1"

  if grep -Fq 'What should Claude do instead?' <<<"$recent"; then
    return 0
  fi

  if grep -Fq "Unrecognized command '/" <<<"$recent"; then
    return 0
  fi

  if grep -Eq 'no such file or directory: /|command not found: /' <<<"$recent"; then
    return 0
  fi

  return 1
}

tmux_wait_for_ready_prompt() {
  local target="$1"
  local attempts="${2:-15}"
  local attempt recent

  for (( attempt = 1; attempt <= attempts; attempt += 1 )); do
    recent="$(tmux_recent_pane_text "$target")"
    if tmux_recent_has_command_rejection "$recent"; then
      return 1
    fi
    if tmux_pane_ready_for_input "$recent"; then
      return 0
    fi
    sleep 1
  done

  return 1
}

tmux_wait_for_idle_prompt() {
  local target="$1"
  local attempts="${2:-30}"
  local attempt recent

  for (( attempt = 1; attempt <= attempts; attempt += 1 )); do
    recent="$(tmux_recent_pane_text "$target")"
    if tmux_recent_has_command_rejection "$recent"; then
      return 1
    fi
    if tmux_pane_ready_for_input "$recent" && ! tmux_pane_has_live_activity "$recent"; then
      return 0
    fi
    sleep 1
  done

  return 1
}

tmux_send_prompt_line() {
  local target="$1"
  local text="$2"
  local family

  family="$(tmux_pane_family "$target")"
  tmux_wait_for_idle_prompt "$target" 30 || return 1

  case "$family" in
    claude)
      tmux_send_raw_keys "$target" Escape
      tmux_wait_for_ready_prompt "$target" 10 || true
      tmux_send_raw_keys "$target" i
      ;;
    *)
      tmux_prepare_prompt_for_input "$target"
      ;;
  esac

  sleep 0.2
  tmux_send_literal_text "$target" "$text"
  sleep 0.2
  tmux_send_raw_keys "$target" Enter
}

tmux_wait_for_text() {
  local target="$1"
  local needle="$2"
  local attempts="${3:-20}"
  local attempt recent flattened_recent flattened_needle

  # Flatten needle (remove newlines and collapse spaces)
  flattened_needle="$(echo "$needle" | tr -s '[:space:]' ' ' | sed 's/^ //;s/ $//')"

  for (( attempt = 1; attempt <= attempts; attempt += 1 )); do
    recent="$(tmux_recent_pane_text "$target")"
    # Flatten recent text for matching: collapse all whitespace into single spaces
    flattened_recent="$(echo "$recent" | tr -s '[:space:]' ' ')"

    if [[ "$flattened_recent" == *"$flattened_needle"* ]]; then
      return 0
    fi
    sleep 1
  done

  return 1
}

tmux_launch_claude_in_shell() {
  local target="$1"
  local attempts="${2:-60}"
  local attempt

  # Ensure shell is ready for input
  tmux_send_raw_keys "$target" C-c
  sleep 0.5
  tmux_send_raw_keys "$target" C-u
  sleep 0.5

  tmux_wait_for_idle_prompt "$target" 20 || return 2
  tmux_send_literal_text "$target" "claude"
  sleep 0.2
  tmux_send_raw_keys "$target" Enter

  for (( attempt = 1; attempt <= attempts; attempt += 1 )); do
    if [[ "$(tmux_pane_family "$target")" == "claude" ]]; then
      tmux_wait_for_ready_prompt "$target" 15 || true
      return 0
    fi
    sleep 1
  done

  return 1
}

# Reset a worker pane into a clean-ready state for the next kickoff prompt.
#
# Exit codes:
#   0  — pane is ready for a new kickoff instruction
#   1  — /clear did not settle on an agent pane
#   2  — pane was at a shell prompt and claude could not be re-launched
#   3  — pane family is not an agent and not a shell; operator must recover
tmux_reset_session() {
  local target="$1"
  local family clear_command

  family="$(tmux_pane_family "$target")"

  if [[ "$family" == "shell" ]]; then
    # Worker pane has exited back to a shell (e.g., after pytest or a
    # Claude exit). No /clear semantics apply; launch a fresh claude so the
    # kickoff prompt has a UI to land on.
    tmux_launch_claude_in_shell "$target" || return 2
    return 0
  fi

  clear_command="$(tmux_clear_reset_command "$family")" || return 3

  tmux_wait_for_idle_prompt "$target" 30 || return 1
  tmux_send_prompt_line "$target" "$clear_command"
  tmux_wait_for_ready_prompt "$target" || return 1
  sleep 0.5
}

tmux_target_exists() {
  "${tmux_cmd[@]}" list-panes -t "$1" >/dev/null 2>&1
}

tmux_session_exists() {
  "${tmux_cmd[@]}" has-session -t "$1" >/dev/null 2>&1
}

tmux_first_pane_in_session() {
  "${tmux_cmd[@]}" list-panes -t "$1" -F '#S:#I.#P' | head -n 1
}

tmux_create_session() {
  local session="$1"
  if ! tmux_session_exists "$session"; then
    "${tmux_cmd[@]}" new-session -d -s "$session" -n node "$default_shell"
  fi
}

tmux_ensure_pane_target() {
  local target="$1"
  local session window pane current_target attempts

  session="${target%%:*}"
  current_target="${target#*:}"
  window="${current_target%%.*}"
  pane="${current_target##*.}"

  tmux_create_session "$session"

  if tmux_target_exists "$target"; then
    printf '%s\n' "$target"
    return 0
  fi

  if "${tmux_cmd[@]}" list-panes -t "${session}:${window}" >/dev/null 2>&1; then
    :
  else
    "${tmux_cmd[@]}" new-window -d -t "$session" -n node "$default_shell"
  fi

  for attempts in {1..6}; do
    if tmux_target_exists "$target"; then
      printf '%s\n' "$target"
      return 0
    fi
    "${tmux_cmd[@]}" split-window -d -t "${session}:${window}.0" -v "$default_shell"
  done

  if tmux_target_exists "$target"; then
    printf '%s\n' "$target"
    return 0
  fi

  return 1
}

resolve_named_lane_target() {
  local session="$1"
  local desired="${2:-}"
  local target

  if [[ -n "$desired" ]]; then
    target="${session}:${desired}"
    if tmux_target_exists "$target"; then
      printf '%s\n' "$target"
      return 0
    fi
  fi

  if ! tmux_session_exists "$session"; then
    target="${session}:0.0"
    tmux_ensure_pane_target "$target"
    printf '%s\n' "$target"
    return 0
  fi

  # Find the best pane in the session: prefer non-sidebars
  local best_pane=""
  local panes
  panes="$( "${tmux_cmd[@]}" list-panes -t "$session" -F '#{window_index}.#{pane_index}' )"

  for idx in $panes; do
    target="${session}:${idx}"
    if ! tmux_pane_is_sidebar "$target"; then
      best_pane="$target"
      break
    fi
  done

  if [[ -n "$best_pane" ]]; then
    printf '%s\n' "$best_pane"
    return 0
  fi

  # Fallback to 0.0 if all are sidebars or none found
  printf '%s:0.0\n' "$session"
}

resolve_explicit_target() {
  local raw="$1"

  if tmux_target_exists "$raw"; then
    if ! tmux_pane_is_sidebar "$raw"; then
      printf '%s\n' "$raw"
      return 0
    fi
    # If it is a sidebar, try to find a better one in the same window
    local session window
    session="${raw%%:*}"
    window="${raw#*:}"
    window="${window%%.*}"
    local panes
    panes="$( "${tmux_cmd[@]}" list-panes -t "${session}:${window}" -F '#{pane_index}' )"
    for index in $panes; do
      if ! tmux_pane_is_sidebar "${session}:${window}.${index}"; then
        printf '%s:%s.%s\n' "$session" "$window" "$index"
        return 0
      fi
    done
  fi

  local session="${raw%%:*}"
  if tmux_session_exists "$session"; then
    if [[ "$raw" == *.* ]]; then
      tmux_ensure_pane_target "$raw"
      return 0
    fi
    # Search for first non-sidebar pane in the session
    local panes
    panes="$( "${tmux_cmd[@]}" list-panes -t "$session" -F '#{window_index}.#{pane_index}' )"
    for idx in $panes; do
      if ! tmux_pane_is_sidebar "${session}:${idx}"; then
        printf '%s:%s\n' "$session" "$idx"
        return 0
      fi
    done
    tmux_first_pane_in_session "$session"
    return 0
  fi

  tmux_ensure_pane_target "$raw"
}

resolve_worker_target() {
  local worker="$1"
  if [[ "$worker" == *:* ]]; then
    resolve_explicit_target "$worker"
  elif tmux_target_exists "xc:${worker}.1" && ! tmux_pane_is_sidebar "xc:${worker}.1"; then
    printf 'xc:%s.1\n' "$worker"
    return 0
  else
    resolve_named_lane_target "xc-crew-${worker}"
  fi
}

resolve_polecat_target() {
  local polecat="$1"
  if [[ "$polecat" == *:* ]]; then
    resolve_explicit_target "$polecat"
  else
    resolve_named_lane_target "xc-${polecat}"
  fi
}

resolve_earthshot_worker_target() {
  resolve_named_lane_target "xc-crew-earthshot"
}

resolve_earthshot_timer_target() {
  resolve_named_lane_target "xc-crew-earthshot" "0.2"
}
