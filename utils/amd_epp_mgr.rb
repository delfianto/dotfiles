#!/usr/bin/env ruby

require 'shellwords' # For Shellwords.escape when building shell commands
require 'open3'      # For more control over external command execution if needed

class AmdEppManager
  # Define the base path for energy_performance_preference files
  EPP_BASE_PATH = "/sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference".freeze

  # Define the available EPP profiles and their descriptions
  EPP_PROFILES = {
    "performance" => "Prioritizes performance above power saving. CPU reaches higher clock speeds aggressively.",
    "balance_performance" => "Aims for a balance, leaning towards performance. Default in many systems.",
    "balance_power" => "Strikes a balance, leaning towards power saving. More conservative clock speed increases.",
    "power" => "Strongly prioritizes power saving. Favors lower frequencies, may limit peak performance."
  }.freeze

  # Initializes the manager, finding all CPU EPP paths
  def initialize
    @epp_paths = Dir.glob(EPP_BASE_PATH).sort # Sort for consistent ordering
    if @epp_paths.empty?
      stderr_print "Error: No CPU energy preference files found under #{EPP_BASE_PATH.gsub('*', '<cpu_num>')}."
      stderr_print "Ensure your kernel supports AMD EPP and you have appropriate permissions."
      exit 1 # Critical error, exit
    end
  end

  # Prints a message to standard output
  def stdout_print(message)
    puts message
  end

  # Prints a message to standard error
  def stderr_print(message)
    warn message # 'warn' prints to STDERR
  end

  # Displays the help information
  def display_help
    script_name = File.basename($PROGRAM_NAME)
    stdout_print ""
    stdout_print "AmdEppManager: Manage AMD Energy Performance Preference settings."
    stdout_print "Defaults to showing current EPP state (--info) if no arguments are given."
    stdout_print ""
    stdout_print "Usage: #{script_name} [argument]"
    stdout_print "Valid arguments:"
    stdout_print "  -h,  --help                Show this help information."
    stdout_print "  -i,  --info                Show EPP information for all cores (default)."
    stdout_print "  -p0, --max-performance      Set EPP to 'performance'."
    stdout_print "  -p1, --bal-performance    Set EPP to 'balance_performance'."
    stdout_print "  -p2, --bal-powersave      Set EPP to 'balance_power'."
    stdout_print "  -p3, --max-powersave      Set EPP to 'power'."
    stdout_print ""
    stdout_print "EPP Profile Details:"
    EPP_PROFILES.each do |profile, description|
      stdout_print "  #{profile.ljust(22)} - #{description}"
    end
    stdout_print ""
    sudoers_tip_path = @epp_paths.first&.gsub(/cpu\d+/, 'cpu*') || "/sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference"
    stdout_print "For passwordless EPP switching, add to sudoers (via 'sudo visudo'):"
    stdout_print "  <your_username> ALL=(root) NOPASSWD: /usr/bin/tee #{sudoers_tip_path}"
    stdout_print ""
  end

  # Shows the current EPP information for all CPU cores
  def display_info
    output_lines = []
    max_cpu_label_width = 0

    @epp_paths.each do |filepath|
      if File.readable?(filepath)
        # Extract CPU number: e.g., /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference -> 0
        cpu_num_match = filepath.match(%r{/cpu(\d+)/})
        cpu_num_str = cpu_num_match ? cpu_num_match[1] : "N/A"
        cpu_label = sprintf("- CPU%02s", cpu_num_str)
        max_cpu_label_width = [max_cpu_label_width, cpu_label.length].max

        begin
          value = File.read(filepath).strip
          output_lines << { label: cpu_label, value: value }
        rescue SystemCallError => e # More specific error catching for file operations
          stderr_print "Warning: Could not read EPP for #{filepath}: #{e.message}"
          output_lines << { label: cpu_label, value: "Error reading" }
        end
      else
        stderr_print "Warning: EPP file #{filepath} is not readable."
      end
    end

    if output_lines.empty?
      stdout_print "No readable EPP information found for any CPU cores."
      return
    end

    # Print formatted output
    stdout_print "Current AMD EPP Status:"
    output_lines.each do |line|
      stdout_print "#{line[:label].ljust(max_cpu_label_width + 2)}: #{line[:value]}"
    end
  end

  # Sets the EPP value for all CPU cores
  #
  # @param epp_profile_key [String] The key for the EPP_PROFILES hash (e.g., "performance")
  # @return [Boolean] true if successful, false otherwise
  def set_epp_profile(epp_profile_key)
    unless EPP_PROFILES.key?(epp_profile_key)
      stderr_print "Error: Invalid EPP profile '#{epp_profile_key}'."
      stdout_print "Valid profiles are: #{EPP_PROFILES.keys.join(', ')}"
      return false
    end

    epp_value_to_set = epp_profile_key # The actual string value to write, e.g., "performance"

    stdout_print "Attempting to set EPP to '#{epp_value_to_set}' for #{@epp_paths.length} CPU core(s)..."

    # Construct the command: echo 'value' | sudo tee /path/to/epp1 /path/to/epp2 ...
    # Shellwords.escape is used for the epp_value and each path for security.
    escaped_paths = @epp_paths.map { |p| Shellwords.escape(p) }.join(' ')
    command_str = "echo #{Shellwords.escape(epp_value_to_set)} | sudo tee #{escaped_paths}"

    # Execute the command.
    # system() returns true if the command gives zero exit status, false for non-zero.
    # We redirect tee's stdout and stderr to /dev/null to avoid its output cluttering ours.
    stdout_print "Executing: echo '#{epp_value_to_set}' | sudo tee #{@epp_paths.count} files..."
    success = system("#{command_str} > /dev/null 2>&1")

    if success
      stdout_print "Successfully set EPP to '#{epp_value_to_set}' for all detected CPU cores."
      # Optionally, verify by reading back the values
      # display_info
      return true
    else
      # $? contains status of last executed child process
      exit_status = $?.exitstatus
      stderr_print "Error: Failed to set EPP (exit status: #{exit_status})."
      stderr_print "Command attempted: #{command_str.gsub("sudo tee", "sudo tee ...paths...")}" # Avoid overly long output
      stderr_print "Possible reasons:"
      stderr_print "  - Incorrect sudo password entered (if prompted)."
      stderr_print "  - Lack of sudo permissions to run 'tee' on the EPP files."
      stderr_print "  - EPP files are not writable even by root (unlikely but possible)."
      stderr_print "  - The 'tee' command is not found at /usr/bin/tee (less likely)."
      display_sudoers_hint
      return false
    end
  end

  # Helper to show just the sudoers tip
  def display_sudoers_hint
    sudoers_tip_path = @epp_paths.first&.gsub(/cpu\d+/, 'cpu*') || "/sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference"
    stdout_print ""
    stdout_print "Hint: For passwordless operation, add to sudoers (using 'sudo visudo'):"
    stdout_print "  <your_username> ALL=(root) NOPASSWD: /usr/bin/tee #{sudoers_tip_path}"
  end

  # Main method to parse arguments and dispatch actions
  def run(args)
    if args.empty?
      display_info # Default action
      return
    end

    case args[0]
    when '-h', '--help'
      display_help
    when '-i', '--info'
      display_info
    when '-p0', '--max-performance'
      set_epp_profile("performance")
    when '-p1', '--bal-performance'
      set_epp_profile("balance_performance")
    when '-p2', '--bal-powersave'
      set_epp_profile("balance_power")
    when '-p3', '--max-powersave'
      set_epp_profile("power")
    else
      stderr_print "Error: Invalid argument '#{args[0]}'"
      display_help
      exit 1 # Exit with an error code
    end
  end
end

# --- Script Execution ---
if __FILE__ == $PROGRAM_NAME
  # This block runs only when the script is executed directly.
  manager = AmdEppManager.new
  manager.run(ARGV) # ARGV is an array containing command-line arguments
end
