#!/bin/zsh

# Argument Parsing
PARENT_PID=""
MATCH_PATTERNS=()
MATCH_ALL=false

print_usage() {
  cat <<EOF
Usage: $0 [--parent PID] [--match PATTERN ...] [--all] [--help]

Options:
  --parent PID       Track processes spawned by given parent (default: Hyprland)
  --match PATTERN    Match app name or command line (can repeat)
  --all              Match all processes (overrides --match)
  --help             Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent)
      shift
      PARENT_PID="$1"
      ;;
    --match)
      shift
      MATCH_PATTERNS+=("$1")
      ;;
    --all)
      MATCH_ALL=true
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      print_usage
      exit 1
      ;;
  esac
  shift
done

# Set parent PID if not provided
if [[ -z "$PARENT_PID" ]]; then
  PARENT_PID=$(pidof Hyprland | awk '{print $1}')
  if [[ -z "$PARENT_PID" ]]; then
    echo "Error: Could not determine Hyprland PID. Use --parent PID." >&2
    exit 1
  fi
fi

# Recursively Find Child PIDs
get_descendants() {
  local pid=$1
  local result=()
  local children

  children=("${(f)$(ps -eo pid,ppid --no-header | awk -v p=$pid '$2 == p {print $1}')}")

  for child in $children; do
    result+=($child)
    result+=($(get_descendants $child))
  done

  echo $result
}

# Main logic
descendants=($(get_descendants $PARENT_PID))

latest_pid=""
latest_time=0
latest_cmdline=""

for pid in $descendants; do
  if [[ -r "/proc/$pid/comm" && -r "/proc/$pid/cmdline" && -r "/proc/$pid" ]]; then
    cmd_name=$(</proc/$pid/comm)
    cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline)
    match=false

    if $MATCH_ALL; then
      match=true
    elif [[ ${#MATCH_PATTERNS[@]} -gt 0 ]]; then
      for pattern in $MATCH_PATTERNS; do
        if [[ "$cmd_name" == *$pattern* || "$cmdline" == *$pattern* ]]; then
          match=true
          break
        fi
      done
    fi

    if $match; then
      start_time=$(stat -c %Y /proc/$pid 2>/dev/null)
      if (( start_time > latest_time )); then
        latest_time=$start_time
        latest_pid=$pid
        latest_cmdline=$cmdline
      fi
    fi
  fi
done

# Output
if [[ -n "$latest_pid" ]]; then
  echo "Latest matched process:"
  echo "  PID: $latest_pid"
  echo "  Started: $(date -d @$latest_time)"
  echo "  Command: $latest_cmdline"
else
  echo "No matching child process found under PID $PARENT_PID"
fi
