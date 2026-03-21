#!/usr/bin/env bash
set -euo pipefail

tmux_cmd=(/opt/homebrew/bin/tmux -L gt)
default_shell="${SHELL:-/bin/zsh} -l"

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

tmux_wait_for_ready_prompt() {
  local target="$1"
  local attempts="${2:-15}"
  local attempt recent

  for (( attempt = 1; attempt <= attempts; attempt += 1 )); do
    recent="$(tmux_recent_pane_text "$target")"
    if tmux_pane_ready_for_input "$recent"; then
      return 0
    fi
    sleep 1
  done

  return 1
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
  local desired="${2:-0.0}"
  local target="${session}:${desired}"

  if tmux_target_exists "$target"; then
    printf '%s\n' "$target"
    return 0
  fi

  if tmux_session_exists "$session"; then
    if [[ "$desired" == "0.0" ]]; then
      local first_pane
      first_pane="$(tmux_first_pane_in_session "$session")"
      if [[ -n "$first_pane" ]]; then
        printf '%s\n' "$first_pane"
        return 0
      fi
    fi
  fi

  tmux_ensure_pane_target "$target"
}

resolve_explicit_target() {
  local raw="$1"

  if tmux_target_exists "$raw"; then
    printf '%s\n' "$raw"
    return 0
  fi

  local session="${raw%%:*}"
  if tmux_session_exists "$session"; then
    if [[ "$raw" == *.* ]]; then
      tmux_ensure_pane_target "$raw"
      return 0
    fi
    tmux_first_pane_in_session "$session"
    return 0
  fi

  tmux_ensure_pane_target "$raw"
}

resolve_worker_target() {
  local worker="$1"
  if [[ "$worker" == *:* ]]; then
    resolve_explicit_target "$worker"
  else
    resolve_named_lane_target "xc-crew-${worker}" "0.0"
  fi
}

resolve_polecat_target() {
  local polecat="$1"
  if [[ "$polecat" == *:* ]]; then
    resolve_explicit_target "$polecat"
  else
    resolve_named_lane_target "xc-${polecat}" "0.0"
  fi
}

resolve_earthshot_worker_target() {
  resolve_named_lane_target "xc-crew-earthshot" "0.0"
}

resolve_earthshot_timer_target() {
  resolve_named_lane_target "xc-crew-earthshot" "0.2"
}
