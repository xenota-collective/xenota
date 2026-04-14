#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"

repo_root="$(
  cd "$script_dir/../../../.." && pwd
)"
target="${1:-xc:0.2}"
config_path="${2:-$repo_root/.xsm-local/swarm-backlog.yaml}"
xsm_bin="${3:-$repo_root/xenon/packages/xsm/.venv/bin/xsm}"

if [[ "$target" != "xc:0.2" ]]; then
  echo "restart_local_xsm: XSM may only run in xc:0.2 (got $target)" >&2
  exit 2
fi

if [[ ! -x "$xsm_bin" ]]; then
  echo "restart_local_xsm: missing executable runtime: $xsm_bin" >&2
  exit 1
fi

if [[ ! -f "$config_path" ]]; then
  echo "restart_local_xsm: missing config: $config_path" >&2
  exit 1
fi

resolved_target="$(resolve_explicit_target "$target")"
pane_dead="$("${tmux_cmd[@]}" display-message -p -t "$resolved_target" '#{pane_dead}')"
current_command="$(tmux_pane_current_command "$resolved_target")"
resolved_config_path="$(cd "$(dirname "$config_path")" && pwd)/$(basename "$config_path")"

respawn_shell() {
  "${tmux_cmd[@]}" respawn-pane -k -t "$resolved_target" "$default_shell"
  sleep 1
}

if [[ "$pane_dead" == "1" ]]; then
  respawn_shell
  pane_dead="$("${tmux_cmd[@]}" display-message -p -t "$resolved_target" '#{pane_dead}')"
  current_command="$(tmux_pane_current_command "$resolved_target")"
fi

if [[ "$current_command" != "zsh" && "$current_command" != "bash" && "$current_command" != "sh" && "$current_command" != "fish" ]]; then
  tmux_send_raw_keys "$resolved_target" C-c
  sleep 1
fi

tmux_send_raw_keys "$resolved_target" Escape
sleep 0.2
tmux_send_raw_keys "$resolved_target" C-c
sleep 0.2
pane_dead="$("${tmux_cmd[@]}" display-message -p -t "$resolved_target" '#{pane_dead}')"
if [[ "$pane_dead" == "1" ]]; then
  respawn_shell
fi
tmux_send_raw_keys "$resolved_target" C-u
sleep 0.2

current_pid="$$"
while IFS= read -r pid; do
  [[ -z "$pid" || "$pid" == "$current_pid" ]] && continue
  kill "$pid" 2>/dev/null || true
done < <(
  ps -axo pid=,command= | awk -v cfg="$resolved_config_path" -v me="$current_pid" '
    index($0, "xsm monitor --config " cfg) > 0 || index($0, "xsm wrangle --config " cfg) > 0 {
      gsub(/^ +/, "", $0)
      split($0, parts, /[[:space:]]+/)
      if (parts[1] != me) {
        print parts[1]
      }
    }
  '
)

launch_cmd="cd \"$repo_root\" && \"$xsm_bin\" wrangle --config \"$resolved_config_path\" --json"
tmux_send_literal_text "$resolved_target" "$launch_cmd"
tmux_send_raw_keys "$resolved_target" Enter

for _ in {1..20}; do
  current_command="$(tmux_pane_current_command "$resolved_target")"
  if [[ "$current_command" != "zsh" && "$current_command" != "bash" && "$current_command" != "sh" && "$current_command" != "fish" ]]; then
    echo "restart_local_xsm: started on $resolved_target via $xsm_bin"
    exit 0
  fi
  sleep 1
done

echo "restart_local_xsm: failed to launch on $resolved_target" >&2
tmux_recent_pane_text "$resolved_target" >&2
exit 1
