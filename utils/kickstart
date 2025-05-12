#!/bin/zsh
# --- Debug / dry-run flag ---
local debug_mode=0

log() {
  local level="$1"
  shift
  local message="$*"

  # Determine script name and truncate/pad to 15 chars
  local script_name="${funcfiletrace[1]##*/}"
  script_name="${script_name:0:15}" # truncate if too long
  printf -v script_name '%-15s' "$script_name"  # pad right

  local process_id="$$"
  printf -v process_id '%-6s' "$process_id"

  local timestamp="$(date '+%Y-%m-%d:%H:%M:%S')"

  # Color codes
  local color_reset=$'\e[0m'
  local color_debug=$'\e[36m'
  local color_info=$'\e[32m'
  local color_warn=$'\e[33m'
  local color_error=$'\e[31m'

  # Format and color level
  local raw_level="${level:0:5}"
  printf -v raw_level '%-5s' "$raw_level"
  local colored_level
  case "$level" in
    DEBUG) colored_level="${color_debug}${raw_level}${color_reset}" ;;
    INFO)  colored_level="${color_info}${raw_level}${color_reset}" ;;
    WARN)  colored_level="${color_warn}${raw_level}${color_reset}" ;;
    ERROR) colored_level="${color_error}${raw_level}${color_reset}" ;;
    *)     colored_level="$raw_level" ;;
  esac

  # Final aligned log line
  echo "[$script_name:$process_id:$timestamp][$colored_level] $message"
}

pad() {
  local var="$1"
  local width="${2:-10}"   # Default width = 10
  local align="${3:-left}" # Options: left or right

  if [[ "$align" == "right" ]]; then
    printf "%${width}s" "$var"
  else
    printf "%-${width}s" "$var"
  fi
}

pad_log() {
  local prefix="$1"
  local item="$2"
  local width="${3:-12}"   # Total width inside the brackets
  local align="${4:-left}" # left or right alignment

  local content="${prefix}:${item}"
  local pad_fmt

  if [[ "$align" == "right" ]]; then
    pad_fmt="%${width}s"
  else
    pad_fmt="%-${width}s"
  fi

  printf "[${pad_fmt}]\n" "$content"
}

check_exec() {
  if (( ! ${+commands[$1]} )); then
    log ERROR "'$1' command is not installed"
    exit 1
  fi
}

slurp() {
  dasel -f $config_file -r yaml "$1"
}

init_config() {
  # --- Check if config file really exist ---
  config_file=${HYPR_STARTUP_FLOW:-"$HOME/.config/hypr/conf/autostart.yaml"}
  if [[ ! -f "$config_file" ]]; then
    log ERROR "Configuration file not found: $config_file"
    exit 1
  else
    log INFO "Using configuration file: $config_file"
  fi

  # Check the rest of the dependencies
  local exec_names_raw=$(slurp '.exec_names.all()')
  local exec_names=("${(f)exec_names_raw}")

  for exec in "${exec_names[@]}"; do
    check_exec "$exec"
  done

  # --- Read Settings ---
  initial_delay=$(slurp "orDefault(.settings.initial_delay,string(1))")
  inter_desktop_delay=$(slurp "orDefault(.settings.inter_desktop_delay,string(0.5))")
  inter_app_delay=$(slurp "orDefault(.settings.inter_app_delay,string(0.5))")
  delay_jitter=$(slurp "orDefault(.settings.delay_jitter,string(0.2))")

  default_workspace=$(slurp "orDefault(.settings.default_workspace,string(home))")
  main_mod=$(slurp "orDefault(.settings.main_mod,string(SUPER))")

  # Validate numeric values (basic check)
  for val in "$initial_delay" "$inter_desktop_delay" "$inter_app_delay" "$delay_jitter"; do
    [[ "$val" =~ ^[0-9]+(\.[0-9]+)?$ ]] || {
      log ERROR "Invalid numeric value in config: $val"
      exit 1
    }
  done
}

smart_sleep() {
  local base_delay="$1"; shift
  local jitter="${1:-0}"

  local entropy=$(( $(date +%s%N) ^ $$ ^ RANDOM ))
  local final_delay=$(awk -v base="$base_delay" -v jit="$jitter" \
    -v seed="$entropy" 'BEGIN { srand(seed); print base + (rand() * jit) }'
  )

  local sleep_log="for ${final_delay}s (base=$base_delay, jitter=$jitter) before next action"

  if (( debug_mode )); then
    log DEBUG "Simulating delay $sleep_log"
    return
  fi

  log DEBUG "Sleeping $sleep_log"
  sleep "$final_delay"
}

move_window_to_workspace() {
  local pid="$1"
  local target_workspace="$2"
  local max_tries=30
  local sleep_interval=0.2

  log INFO "Waiting for window with PID '$pid' to move to workspace $target_workspace"

  for ((i = 0; i < max_tries; i++)); do
    local clients_json=$(hyprctl clients -j 2>/dev/null)
    local address=$(echo "$clients_json" | jq -r ".[] | select(.pid == $pid) | .address")

    if [[ -n "$address" && "$address" != "null" ]]; then
      log INFO "Found window $address (pid $pid), moving to workspace $target_workspace"
      hyprctl dispatch "movetoworkspace $target_workspace,address:$address"
      return 0
    fi

    sleep "$sleep_interval"
  done

  log WARN "Window with PID $pid not found after ${max_tries} tries"
  return 1
}

expand_and_run() {
  local exec="$1"; shift
  local filter="$1"; shift
  log INFO "$ex_log Dasel filter arguments: $filter"

  # Use Zsh's ${(f)"$(...)"} parameter expansion flag to read lines into a zsh array.
  # This also correctly handles arguments with spaces.
  local cmd_args_raw="$(slurp "$filter" 2> /dev/null)"
  local cmd_args=( ${(f)cmd_args_raw} )

  # Perform safe expansion on arguments (e.g., $HOME -> /home/user)
  local expanded_args=()

  # Check if cmd_args is empty
  if [[ -z "$cmd_args_raw" ]]; then
    log WARN "$ex_log No extra arguments found for command"
  else
    local arg; for arg in "${cmd_args[@]}"; do
      # Use zsh (e) flag for safe expansion (handles $VAR, ${VAR}, $(...), etc.)
      # Does NOT handle tilde '~'. Use $HOME in JSON config instead.
      local earg="${(e)arg}"
      log INFO "$ex_log Extra arg: $earg"
      expanded_args+=( "${earg}" )
    done
  fi

  if (( ! debug_mode )); then
    log INFO "$ex_log Expanded command: $exec ${expanded_args[*]}"
    # local result=$($exec "${expanded_args[@]}" &)
    # local result_lines=("${(f)result}")

    # local child_pid=$!
    # wait "$child_pid"

    # log INFO "$ex_log Captured PID: $child_pid"
    # move_window_to_workspace "$child_pid" "$workspace"

    # if [[ $? -ne 0 ]]; then
    #   log WARN "$ex_log Command failed with exit code $?"
    # else
    #   local line; for line in "${result_lines[@]}"; do
    #     [[ -n "$line" ]] && log INFO "$exec: $line" || log INFO "$exec: No output"
    #   done
    # fi
    "$exec" "${expanded_args[@]}" &  # No command substitution!
    local child_pid=$!
    log INFO "$ex_log Captured PID: $child_pid"
    wait "$child_pid"
    move_window_to_workspace "$child_pid" "$workspace"
  else
    log DEBUG "$ex_log Dry-run command: $exec ${expanded_args[*]}"
  fi

  smart_sleep $inter_app_delay $delay_jitter
}

run_hooks() {
  local hook_type="$1"
  local workspace="$2"

  log INFO "$ws_log Running $hook_type hook"
  local exec=$(slurp ".hooks.$hook_type.exec" 2> /dev/null)

  # Logging variables
  ex_log="$(pad_log "HK" "$exec")"

  if [[ -n "$exec" ]]; then
    expand_and_run "$exec" ".hooks.$hook_type.args.all()"
  fi
}

run_workspace() {
  # Check if the workspace is a number or a string
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    workspace=$(slurp ".workspaces.[$1].workspace")
    workspace_base=".workspaces.[$1]"
  else
    workspace=$1
    workspace_base=".workspaces.all().filter(equal(workspace,$1))"
  fi

  # Logging variables
  ws_log="$(pad_log "WS" "$workspace")"

  local commands=".$workspace_base.commands"
  local command_count=$(slurp "$commands.len()")

  if [[ -z "$command_count" ]]; then
    log WARN "No commands found for workspace: $1"
    return
  fi

  # Execute the before_each hook if it exists
  log INFO "$ws_log Performing initialization"
  # run_hooks before_each $workspace

  local i; for ((i = 0; i < command_count; i++)); do
    # Extract command and arguments
    local exec=$(slurp "$commands.[$i].exec")

    # Logging variables
    ex_log="$(pad_log "EX" "$exec")"

    # Check if exec command is empty
    if [[ -z "$exec" || "$exec" == "null" ]]; then
      log WARN "$ws_log Skipping command with empty 'exec' at index: $i"
    else
      # Execute the expanded command with arguments
      log INFO "$ex_log Command found"
      expand_and_run $exec "$commands.[$i].args.all()"
    fi
  done

  # local special_flag=$(slurp "$workspace_base.special")
  # log INFO "$ws_log Special flag: $special_flag"
  # if [[ "$special_flag" == "true" ]]; then
  #   local mods_raw=$(slurp "$workspace_base.mods.all()" 2> /dev/null)

  #   if [[ -n "$mods_raw" ]]; then
  #     local mods=("${(f)mods_raw}")
  #     log INFO "$ws_log Using key modifiers: $main_mod ${mods[*]}"
  #     run_hooks bind_special $workspace
  #   fi
  # fi
}

run_all_workspace() {
  # Get total workspace from config
  local num_workspaces=$(slurp ".workspaces.len()")
  if (( num_workspaces == 0 )); then
    log ERROR "No workspaces configurations found in config file"
    exit 1
  fi

  # Loop through each workspace entry
  log INFO "Found $num_workspaces workspace configurations"
  local i; for ((i = 0; i < num_workspaces; i++)); do
    # log INFO "$i: performing workspace initialization"
    run_workspace "$i"
  done
}

# --- Main script execution ---
if [[ "$1" == "--debug" ]]; then
  debug_mode=1
  log DEBUG "Debug mode enabled. No actual commands will be executed"
  shift
fi

check_exec dasel && init_config
log INFO "Starting Hypr startup flow"
smart_sleep $initial_delay $delay_jitter

[[ -z "$1" ]] && {
  log INFO "No workspace specified. Running all workspaces"
  run_all_workspace
} || {
  log INFO "Running specific workspace: $1"
  run_workspace "$1"
}

log INFO "Hypr startup flow completed"
