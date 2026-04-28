#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tmux_target.sh"

repo_root="$(
  cd "$script_dir/../../../.." && pwd
)"
target_input="${1:-xc:0.2}"
config_path="${2:-$repo_root/.xsm-local/swarm-backlog.yaml}"
xsm_bin="${3:-$repo_root/xenon/packages/xsm/.venv/bin/xsm}"

# xc-6tdu2: Resolve the xsm runtime pane via the ``@xsm_role=runtime``
# tmux user option instead of relying on the literal ``xc:0.2`` index.
# Pane indices shift when the workmux sidebar is toggled, so a
# legacy-index default can collide with the wrong pane after a layout
# change. The tag is set on the runtime pane after every successful
# launch (see tag_xsm_runtime_pane below) so subsequent restarts find
# the same physical pane even if the operator hides/shows the sidebar.
runtime_panes=()
while IFS= read -r runtime_pane_line; do
  [[ -n "$runtime_pane_line" ]] || continue
  runtime_panes+=("$runtime_pane_line")
done < <(resolve_xsm_runtime_pane xc 2>/dev/null || true)

if (( ${#runtime_panes[@]} > 1 )); then
  echo "restart_local_xsm: multiple panes are tagged @xsm_role=runtime: ${runtime_panes[*]}" >&2
  echo "restart_local_xsm: clear extras with: tmux set-option -p -t <pane> -u @xsm_role" >&2
  exit 2
fi

if (( ${#runtime_panes[@]} == 1 )); then
  target="${runtime_panes[0]}"
elif [[ "$target_input" == xc:* ]]; then
  target="$target_input"
else
  echo "restart_local_xsm: target must be a pane in the xc session (got $target_input)" >&2
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

# xc-3c4d: codex/rustls subprocesses (invoked via xr) need a CA bundle.
# macOS keychain-native-roots fails for codex when run as a subprocess from
# xsm's process tree; supplying SSL_CERT_FILE / NODE_EXTRA_CA_CERTS as a
# fallback prevents the classifier from crashing and taking xsm with it.
ca_bundle=""
for candidate in /etc/ssl/cert.pem /opt/homebrew/etc/ca-certificates/cert.pem /etc/ssl/certs/ca-certificates.crt; do
  if [[ -r "$candidate" ]]; then
    ca_bundle="$candidate"
    break
  fi
done
env_prefix=""
if [[ -n "$ca_bundle" ]]; then
  env_prefix="SSL_CERT_FILE=\"$ca_bundle\" NODE_EXTRA_CA_CERTS=\"$ca_bundle\" "
fi

# xc-twaa6: xsm gracefully self-exits (rc=0 or rc=75 EX_TEMPFAIL — see
# xsm/main.py raise SystemExit(75)) when its source files change so a
# fresh interpreter can pick up new code. Delegate to the relaunch-loop
# helper so graceful exits trigger automatic relaunch within ~3s instead
# of leaving the pane idle until the supervisor or operator notices. The
# helper is unit-tested under test_xsm_relaunch_loop.sh.
relaunch_loop_script="$script_dir/xsm_relaunch_loop.sh"
launch_cmd="cd \"$repo_root\" && ${env_prefix}\"$relaunch_loop_script\" \"$xsm_bin\" \"$resolved_config_path\""
tmux_send_literal_text "$resolved_target" "$launch_cmd"
tmux_send_raw_keys "$resolved_target" Enter

for _ in {1..20}; do
  current_command="$(tmux_pane_current_command "$resolved_target")"
  if [[ "$current_command" != "zsh" && "$current_command" != "bash" && "$current_command" != "sh" && "$current_command" != "fish" ]]; then
    # xc-6tdu2: Tag the running pane so future restarts can find it via
    # @xsm_role=runtime rather than the fragile xc:0.2 index hint.
    tag_xsm_runtime_pane "$resolved_target" || true
    echo "restart_local_xsm: started on $resolved_target via $xsm_bin"
    exit 0
  fi
  sleep 1
done

echo "restart_local_xsm: failed to launch on $resolved_target" >&2
tmux_recent_pane_text "$resolved_target" >&2
exit 1
