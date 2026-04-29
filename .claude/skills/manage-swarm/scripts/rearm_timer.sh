#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"
source "$script_dir/resolve_repo_root.sh"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <seconds> [state-file]" >&2
  exit 2
fi

seconds="$1"
state_file="${2:-/Users/jv/gt/xenota/crew/earthshot/swarm-state.yaml}"

if ! [[ "$seconds" =~ ^[0-9]+$ ]]; then
  echo "seconds must be an integer" >&2
  exit 2
fi

if [[ ! -f "$state_file" ]]; then
  echo "state file not found: $state_file" >&2
  exit 1
fi

wrangle_count="$(
  awk -F': *' '$1 == "wrangle_count" {print $2; exit}' "$state_file"
)"

if ! [[ "$wrangle_count" =~ ^[0-9]+$ ]]; then
  echo "could not parse wrangle_count from $state_file" >&2
  exit 1
fi

next_wrangle_count=$((wrangle_count + 1))

repo_root=""
if repo_root="$(resolve_xenota_repo_root "$script_dir" 2>/dev/null)"; then
  :
else
  repo_root=""
fi
xsm_config="${XSM_CONFIG:-}"
if [[ -z "$xsm_config" && -n "$repo_root" ]]; then
  xsm_config="$repo_root/.xsm-local/swarm-backlog.yaml"
fi

rearm_configured_supervisor_target() {
  local config_path="$1"

  [[ -n "$config_path" && -f "$config_path" ]] || return 1
  awk '
    /^[[:space:]]*-[[:space:]]*name:[[:space:]]*main[[:space:]]*$/ {
      in_main = 1
      next
    }
    /^[[:space:]]*-[[:space:]]*name:/ {
      in_main = 0
      next
    }
    in_main && /^[[:space:]]*session:[[:space:]]*/ {
      sub(/^[[:space:]]*session:[[:space:]]*/, "")
      gsub(/["'\''"]/, "")
      print
      exit
    }
  ' "$config_path"
}

rearm_pane_command_is_timer_safe() {
  local command="$1"

  case "$command" in
    zsh|bash|sh|fish|sleep)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

rearm_target_is_timer_safe() {
  local target="$1"
  local current_command

  tmux_target_exists "$target" || return 1
  tmux_pane_is_sidebar "$target" && return 1
  current_command="$(tmux_pane_current_command "$target" 2>/dev/null || true)"
  rearm_pane_command_is_timer_safe "$current_command"
}

resolve_rearm_worker_target() {
  local configured_target="$1"
  local candidate

  if [[ -n "$configured_target" ]]; then
    printf 'main\n'
    return 0
  fi

  for candidate in "${configured_target}.1" "xc:supervisor.1"; do
    [[ -n "$configured_target" || "$candidate" == "xc:supervisor.1" ]] || continue
    if tmux_target_exists "$candidate" && ! tmux_pane_is_sidebar "$candidate"; then
      printf 'main\n'
      return 0
    fi
  done

  resolve_earthshot_worker_target
}

resolve_rearm_timer_target() {
  local configured_target="$1"
  local candidate index

  for index in 2 3; do
    if [[ -n "$configured_target" ]]; then
      candidate="${configured_target}.${index}"
      if rearm_target_is_timer_safe "$candidate"; then
        printf '%s\n' "$candidate"
        return 0
      fi
    fi

    candidate="xc:supervisor.${index}"
    if rearm_target_is_timer_safe "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if rearm_target_is_timer_safe "xc:0.3"; then
    printf 'xc:0.3\n'
    return 0
  fi

  resolve_earthshot_timer_target
}

configured_supervisor_target="$(rearm_configured_supervisor_target "$xsm_config" 2>/dev/null || true)"

tmp_file="$(mktemp)"
awk -v next_count="$next_wrangle_count" '
  BEGIN { updated = 0 }
  /^wrangle_count:[[:space:]]*[0-9]+([[:space:]]*#.*)?$/ && updated == 0 {
    print "wrangle_count: " next_count
    updated = 1
    next
  }
  { print }
  END {
    if (updated == 0) {
      exit 1
    }
  }
' "$state_file" > "$tmp_file" || {
  rm -f "$tmp_file"
  echo "failed to update wrangle_count in $state_file" >&2
  exit 1
}
mv "$tmp_file" "$state_file"

timer_target="$(resolve_rearm_timer_target "$configured_supervisor_target")"

if (( next_wrangle_count % 5 == 0 )); then
  arm_cmd="sleep ${seconds}; ${script_dir}/restart_wrangle.sh"
else
  worker_target="$(resolve_rearm_worker_target "$configured_supervisor_target")"
  printf -v quoted_worker '%q' "$worker_target"
  arm_cmd="sleep ${seconds}; ${script_dir}/send_worker_message.sh ${quoted_worker} 'wrangle the swarm'"
fi

"${tmux_cmd[@]}" clear-history -t "$timer_target"
"${tmux_cmd[@]}" respawn-pane -k -t "$timer_target" "$arm_cmd"
