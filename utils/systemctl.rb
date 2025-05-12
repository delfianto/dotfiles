#!/usr/bin/env ruby
# systemctl.rb ~ Ruby wrapper for systemctl with automatic sudo

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

# --- Configurations ---
# Map short aliases to systemctl commands and indicate if sudo is needed by default
# Format: alias => [systemctl_command, needs_sudo_by_default, check_status_afterwards, *extra_args]
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

# --- Main class ---
class Systemctl
  def initialize(argv)
    @original_argv = argv.dup # Keep original args if needed later
    @args = argv.dup          # Work on a copy

    @user_mode = false
    @cmd_base = ['systemctl']

    # Check for user mode flag at the beginning
    if ['user', '-u'].include?(@args.first)
      @user_mode = true
      @cmd_base << '--user'
      @args.shift # Remove 'user' or '-u'
    end
  end

  # Main execution method
  def run
    # Handle edge cases: no command given
    if @args.empty?
      return handle_no_command
    end

    # Extract command keyword
    command_keyword = @args.shift
    units_and_options = @args # Remaining args are units or options

    # Handle help command explicitly
    if ['help', '-h', '--help'].include?(command_keyword)
      print_usage
      return 0 # Exit code 0 for help
    end

    # Handle 'is' command specially
    if command_keyword == 'is'
      return handle_is_command(units_and_options)
    end

    # Handle 'daemon-reload' special case
    if command_keyword == 'daemon'
      return handle_daemon_command(units_and_options)
    end

    # Map the keyword to a systemctl command or handle unknown commands
    mapped = COMMAND_MAP[command_keyword]
    if mapped
      systemctl_cmd, needs_sudo_default, check_status_after, *extra_args = mapped
    else
      # Pass unknown commands directly
      warn "Info: Passing unknown command '#{command_keyword}' directly to systemctl without sudo."
      systemctl_cmd = command_keyword
      needs_sudo_default = false
      check_status_after = false
      extra_args = []
    end

    # Check if sudo is actually needed and execute the main command
    use_sudo = needs_sudo_default && !@user_mode
    full_command = @cmd_base + [systemctl_cmd] + extra_args + units_and_options
    exit_code = execute_command(full_command, use_sudo)

    # Check status after successful command execution when needed
    run_status_check(exit_code, check_status_after, units_and_options)

    exit_code
  end

  private # Private methods below this line

  # Handles the case where no command was provided after 'sc' or 'sc user'
  def handle_no_command
    if @user_mode
      # Default action for 'sc user': list user services
      execute_command(@cmd_base + ['list-units', '--type=service'], false) # No sudo for user
    else
      # Default action for 'sc': show help
      print_usage
      0 # Exit code 0 for help
    end
  end

  # Handles the special 'is' command
  def handle_is_command(units)
    overall_rc = 0
    if units.empty?
      warn "Usage: sc [user|-u] is <unit...>"
      print_usage
      return 1
    end

    units.each do |unit|
      # Use Open3.capture2e to get output and status, suppressing output
      _out_err_en, status_en = Open3.capture2e(*@cmd_base, 'is-enabled', unit)
      _out_err_act, status_act = Open3.capture2e(*@cmd_base, 'is-active', unit)
      _out_err_fail, status_fail = Open3.capture2e(*@cmd_base, 'is-failed', unit)

      # Check exit codes carefully based on systemctl documentation
      enabled_ok = status_en.success? || status_en.exitstatus == 1
      active_ok  = status_act.success? || status_act.exitstatus == 3
      failed_ok  = status_fail.success? || status_fail.exitstatus == 1

      unless enabled_ok && active_ok && failed_ok
        warn "Error checking status for #{unit} (enabled: #{status_en.exitstatus}, active: #{status_act.exitstatus}, failed: #{status_fail.exitstatus})"
        overall_rc = 1
        next # Skip printing for this unit if any check had a real error
      end

      is_enabled = status_en.success? # 0 = enabled
      is_active = status_act.success? # 0 = active
      is_failed = status_fail.success? # 0 = failed

      printf "%s%-15s%s enabled: %s%5s%s; active: %s%5s%s; failed: %s%5s%s\n",
             UNIT_NAME_COLOR, unit, RESET_COLOR,
             is_enabled ? ENABLED_COLOR : DISABLED_COLOR, is_enabled.to_s, RESET_COLOR,
             is_active ? ACTIVE_COLOR : INACTIVE_COLOR, is_active.to_s, RESET_COLOR,
             is_failed ? FAILED_COLOR : NOT_FAILED_COLOR, is_failed.to_s, RESET_COLOR
    end
    overall_rc
  end

  # Handles the special 'daemon-reload' command
  def handle_daemon_command(units_and_options)
    if !units_and_options.empty?
      warn "Error: 'daemon' command takes no unit arguments."
      print_usage
      return 1
    end
    mapped = COMMAND_MAP['daemon']
    systemctl_cmd, needs_sudo_default, _ = mapped
    use_sudo = needs_sudo_default && !@user_mode
    execute_command(@cmd_base + [systemctl_cmd], use_sudo)
  end

  # Executes a system command, optionally with sudo
  def execute_command(command_array, use_sudo)
    final_command = command_array.dup
    sudo_prefix = []

    if use_sudo
      unless sudo_available?
        warn "Warning: sudo command not found, cannot elevate privileges for '#{command_array.join(' ')}'."
        return 255 # Indicate failure due to missing sudo
      end
      sudo_prefix = ['sudo']
    end

    full_cmd_array = sudo_prefix + final_command
    puts "==> Executing: #{full_cmd_array.shelljoin}"

    # Use system with splat operator (*) for security and correct handling
    system(*full_cmd_array)
    $?.exitstatus # Return the exit status
  end

  # Runs a status check after certain successful commands
  def run_status_check(exit_code, check_needed, units_and_options)
      return unless check_needed && exit_code == 0 && !units_and_options.empty?

      # Filter out options (args starting with '-') to get only unit names
      units_for_status = units_and_options.reject { |arg| arg.start_with?('-') }
      return if units_for_status.empty?

      puts "--> Checking status after command..."
      status_command = @cmd_base + ['status'] + units_for_status
      # Status check usually doesn't need sudo, even for system units
      execute_command(status_command, false)
      # We don't return the status check's exit code, only the main command's
  end

  # Checks if the 'sudo' command is available
  def sudo_available?
    system('command -v sudo > /dev/null 2>&1')
  end

  # Prints the usage instructions
  def print_usage
    # (Usage string content is identical to your original script)
    # Using a heredoc for readability
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
      st|status       Show unit status (systemctl status)
      on|start        Start unit(s) (systemctl start)
      off|stop        Stop unit(s) (systemctl stop)
      re|restart      Restart unit(s) (systemctl restart)
      rl|reload       Reload unit(s) configuration (systemctl reload)
      tr|try-restart  Try to restart unit(s) (systemctl try-restart)
      en|enable       Enable unit(s) to start on boot (systemctl enable)
                      Use 'en --now <unit>' to enable and start immediately.
      dis|disable     Disable unit(s) (systemctl disable)
      mask            Mask unit(s), making them impossible to start (systemctl mask)
      unmask          Unmask unit(s) (systemctl unmask)

      is              Check enabled, active, and failed states for unit(s)
      is-en           Check if unit(s) are enabled (systemctl is-enabled)
      is-act          Check if unit(s) are active (systemctl is-active)
      is-fail         Check if unit(s) failed (systemctl is-failed)

      ls|list         List loaded units (systemctl list-units)
      lsf|list-files  List installed unit files (systemctl list-unit-files)
      lst|list-timers List systemd timers (systemctl list-timers --all)

      cat             Show unit file contents (systemctl cat)
      edit            Edit unit file (systemctl edit)
      daemon          Reload systemd manager configuration (systemctl daemon-reload)

      reboot          Reboot the system (systemctl reboot)
      poweroff        Shutdown the system (systemctl poweroff)
      suspend         Suspend the system (systemctl suspend)
      hibernate       Hibernate the system (systemctl hibernate)

      [user|-u]       Operate on the user's service manager (systemctl --user ...)
      help|-h|--help  Show this help message

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
end # End of Systemctl class

# --- Entry point ---
if $PROGRAM_NAME == __FILE__
  # Create an instance of the wrapper, passing command-line
  # arguments and exit the script with resulting exit code
  exit Systemctl.new(ARGV).run
end
