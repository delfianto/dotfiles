#!/bin/zsh

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
