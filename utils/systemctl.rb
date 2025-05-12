#!/usr/bin/env ruby
# systemctl.rb ~ wrapper for systemctl with automatic sudo

require 'shellwords'
require 'open3' # For capturing output/status of check commands

# --- Color Constants ---
RESET_COLOR = "\e[0m"
UNIT_NAME_COLOR = "\e[1;34m"  # Bold Blue
ENABLED_COLOR = "\e[0;32m"    # Green
DISABLED_COLOR = "\e[0;31m"   # Red
ACTIVE_COLOR = "\e[0;32m"     # Green
INACTIVE_COLOR = "\e[0;31m"   # Red
FAILED_COLOR = "\e[0;31m"     # Red
NOT_FAILED_COLOR = "\e[0;32m" # Green

# --- Configuration ---
# Map short aliases to systemctl commands and indicate if sudo is needed by default
# Format: alias => [systemctl_command, needs_sudo_by_default, check_status_afterwards]
COMMAND_MAP = {
  'st' => ['status', false, false], 'status' => ['status', false, false],
  'on' => ['start', true, true], 'start' => ['start', true, true],
  'off' => ['stop', true, true], 'stop' => ['stop', true, true],
  're' => ['restart', true, true], 'restart' => ['restart', true, true],
  'rl' => ['reload', true, true], 'reload' => ['reload', true, true],
  'tr' => ['try-restart', true, true], 'try-restart' => ['try-restart', true, true],
  'en' => ['enable', true, true], 'enable' => ['enable', true, true],
  'dis' => ['disable', true, true], 'disable' => ['disable', true, true],
  'mask' => ['mask', true, true],
  'unmask' => ['unmask', true, true],
  'is-en' => ['is-enabled', false, false], 'is-enabled' => ['is-enabled', false, false],
  'is-act' => ['is-active', false, false], 'is-active' => ['is-active', false, false],
  'is-fail' => ['is-failed', false, false], 'is-failed' => ['is-failed', false, false],
  'ls' => ['list-units', false, false], 'list' => ['list-units', false, false],
  'lsf' => ['list-unit-files', false, false], 'list-files' => ['list-unit-files', false, false],
  'lst' => ['list-timers', false, false, '--all'], 'list-timers' => ['list-timers', false, false, '--all'], # Note extra arg
  'cat' => ['cat', false, false],
  'edit' => ['edit', true, false],
  'daemon' => ['daemon-reload', true, false], # Special case: no unit args allowed
  'reboot' => ['reboot', true, false],
  'poweroff' => ['poweroff', true, false],
  'suspend' => ['suspend', true, false],
  'hibernate' => ['hibernate', true, false],
  # 'is' is handled specially
  # 'help', '-h', '--help' are handled specially
}.freeze

# --- Helper Functions ---
def print_usage
  puts <<~EOF
  Usage: sc [user|-u] <command> [unit...] [systemctl_options...]

  Ruby wrapper for the systemctl command. Automatically uses 'sudo' for commands
  that typically require root privileges when operating on system units (not user units).

  Commands require sudo automatically (for system units):
    on|start, off|stop, re|restart, rl|reload, tr|try-restart,
    en|enable, dis|disable, mask, unmask, daemon, edit,
    reboot, poweroff, suspend, hibernate

  Commands run without sudo automatically:
    st|status, is, is-en, is-act, is-fail, ls|list, lsf|list-files,
    lst|list-timers, cat, help

  Use 'sudo sc ...' explicitly for other commands needing elevation.

  Commands:
    st|status        Show unit status (systemctl status)
    on|start         Start unit(s) (systemctl start)
    off|stop         Stop unit(s) (systemctl stop)
    re|restart       Restart unit(s) (systemctl restart)
    rl|reload        Reload unit(s) configuration (systemctl reload)
    tr|try-restart   Try to restart unit(s) (systemctl try-restart)
    en|enable        Enable unit(s) to start on boot (systemctl enable)
                     Use 'en --now <unit>' to enable and start immediately.
    dis|disable      Disable unit(s) (systemctl disable)
    mask             Mask unit(s), making them impossible to start (systemctl mask)
    unmask           Unmask unit(s) (systemctl unmask)

    is               Check enabled, active, and failed states for unit(s)
    is-en            Check if unit(s) are enabled (systemctl is-enabled)
    is-act           Check if unit(s) are active (systemctl is-active)
    is-fail          Check if unit(s) failed (systemctl is-failed)

    ls|list          List loaded units (systemctl list-units)
    lsf|list-files   List installed unit files (systemctl list-unit-files)
    lst|list-timers  List systemd timers (systemctl list-timers --all)

    cat              Show unit file contents (systemctl cat)
    edit             Edit unit file (systemctl edit)
    daemon           Reload systemd manager configuration (systemctl daemon-reload)

    reboot           Reboot the system (systemctl reboot)
    poweroff         Shutdown the system (systemctl poweroff)
    suspend          Suspend the system (systemctl suspend)
    hibernate        Hibernate the system (systemctl hibernate)

    [user|-u]        Operate on the user's service manager (systemctl --user ...)
    help|-h|--help   Show this help message

  Examples:
    sc status nginx.service         # No sudo needed
    sc start nginx.service          # Runs: sudo systemctl start nginx.service
    sc user start my-app.service    # Runs: systemctl --user start my-app.service (NO sudo)
    sc enable --now bluetooth       # Runs: sudo systemctl enable --now bluetooth
    sc is bluetooth cups            # No sudo needed
    sudo sc set-property foo CPUQuota=10% # Explicit sudo for unhandled command

  Any other command or unrecognized first argument is passed directly to systemctl *without* automatic sudo.
  EOF
end

# Checks if sudo command is available in PATH
def sudo_available?
  system('command -v sudo > /dev/null 2>&1')
end

# Executes a system command, optionally with sudo, and prints the command
def run_command(command_array, use_sudo)
  final_command = command_array.dup # Avoid modifying the original array
  sudo_prefix = []

  if use_sudo
    if sudo_available?
      sudo_prefix = ['sudo']
    else
      warn "Warning: sudo command not found, cannot elevate privileges for '#{command_array.join(' ')}'."
      return 255 # Indicate failure due to missing sudo
    end
  end

  full_cmd_array = sudo_prefix + final_command
  puts "==> Executing: #{full_cmd_array.shelljoin}" # Use shelljoin for safe display

  # system() replaces the current process with the command when given a single string,
  # but executes it as a child process when given multiple arguments.
  # The latter form is safer as it avoids shell interpretation issues.
  system(*full_cmd_array)

  # Return the exit status of the executed command
  $?.exitstatus
end

# --- Handle 'is' command separately ---
# Combine short status checks (enabled, active, failed) for one or more units
def handle_is_command(base_cmd, units)
  overall_rc = 0
  if units.empty?
    warn "Usage: sc [user|-u] is <unit...>"
    print_usage
    return 1
  end

  units.each do |unit|
    # Use Open3.capture2e to get output and status, suppressing output during the check
    _stdout_stderr_en, status_en = Open3.capture2e(*base_cmd, 'is-enabled', unit)
    _stdout_stderr_act, status_act = Open3.capture2e(*base_cmd, 'is-active', unit)
    _stdout_stderr_fail, status_fail = Open3.capture2e(*base_cmd, 'is-failed', unit)

    # systemctl is-enabled: 0=enabled, 1=disabled, >1=error
    # systemctl is-active:  0=active, 3=inactive, >3=error
    # systemctl is-failed:  0=failed, 1=not failed, >1=error

    if !status_en.success? && status_en.exitstatus != 1
      warn "Error checking enabled status for #{unit}"
      overall_rc = 1
      next
    end
    is_enabled = status_en.success? # exit code 0

    if !status_act.success? && status_act.exitstatus != 3
      warn "Error checking active status for #{unit}"
      overall_rc = 1
      next
    end
    is_active = status_act.success? # exit code 0

    if !status_fail.success? && status_fail.exitstatus != 1
      warn "Error checking failed status for #{unit}"
      overall_rc = 1
      next
    end
    is_failed = status_fail.success? # exit code 0

    printf "%s%-15s%s enabled: %s%5s%s; active: %s%5s%s; failed: %s%5s%s\n",
      UNIT_NAME_COLOR, unit, RESET_COLOR,
      is_enabled ? ENABLED_COLOR : DISABLED_COLOR, is_enabled.to_s, RESET_COLOR,
      is_active ? ACTIVE_COLOR : INACTIVE_COLOR, is_active.to_s, RESET_COLOR,
      is_failed ? FAILED_COLOR : NOT_FAILED_COLOR, is_failed.to_s, RESET_COLOR
  end

  return overall_rc
end

# --- Main Logic ---
args = ARGV.dup # Work on a copy of the arguments
user_mode = false
cmd_base = ['systemctl']

# Check for user mode flag
if ['user', '-u'].include?(args.first)
  user_mode = true
  cmd_base << '--user'
  args.shift # Remove 'user' or '-u'
end

# Handle edge cases: no command given
if args.empty?
  if user_mode
    # Default action for 'sc user': list user services
    run_command(cmd_base + ['list-units', '--type=service'], false) # No sudo for user
    exit $?.exitstatus
  else
    # Default action for 'sc': show help
    print_usage
    exit 0
  end
end

command_keyword = args.shift # Get the command keyword and remove it from args
systemctl_cmd = nil
needs_sudo_default = false
check_status_after = false
extra_args = [] # For commands like list-timers that have built-in options

# Handle help command explicitly
if ['help', '-h', '--help'].include?(command_keyword)
  print_usage
  exit 0
end

# Handle 'is' command specially
if command_keyword == 'is'
  exit_code = handle_is_command(cmd_base, args)
  exit exit_code
end

# Handle 'daemon-reload' special case (no unit args)
if command_keyword == 'daemon'
  if !args.empty?
    warn "Error: 'daemon' command takes no unit arguments."
    print_usage
    exit 1
  end
  mapped = COMMAND_MAP[command_keyword]
  systemctl_cmd = mapped[0]
  needs_sudo_default = mapped[1]
  check_status_after = mapped[2] || false # Ensure boolean
else
  # Map the keyword to a systemctl command
  mapped = COMMAND_MAP[command_keyword]
  if mapped
    systemctl_cmd = mapped[0]
    needs_sudo_default = mapped[1]
    check_status_after = mapped[2] || false # Ensure boolean
    extra_args = mapped[3..] || [] # Get any extra args defined in the map
  else
    # If the keyword is not in our map, pass it directly to systemctl
    systemctl_cmd = command_keyword
    needs_sudo_default = false # Don't assume sudo for unknown commands
    check_status_after = false
    warn "Info: Passing unknown command '#{command_keyword}' directly to systemctl without sudo."
  end
end

# Determine if sudo is actually needed (only if default says yes AND not in user mode)
use_sudo = needs_sudo_default && !user_mode

# Construct the full command array
full_command = cmd_base + [systemctl_cmd] + extra_args + args

# Execute the main command
exit_code = run_command(full_command, use_sudo)

# Check status after certain successful commands if needed
if check_status_after && exit_code == 0 && !args.empty?
  # Filter out options (args starting with '-') to get only unit names for status
  units_for_status = args.reject { |arg| arg.start_with?('-') }

  if !units_for_status.empty?
    status_command = cmd_base + ['status'] + units_for_status

    # Run status check WITHOUT sudo since most of the time it is not needed
    # Don't change the overall exit code based on the status check
    run_command(status_command, false)
  end
end

# Exit with the status of the main command executed
exit exit_code
