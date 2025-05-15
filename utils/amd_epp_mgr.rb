#!/usr/bin/env ruby
# frozen_string_literal: true
# amd_epp_mgr.rb ~ Manage AMD Energy Performance Preference (EPP) settings.

require_relative 'lib_checker'
LibChecker.load([
  'optparse',
  'shellwords'
].freeze)

class AmdEppManager
  # Define the base path for energy_performance_preference files
  EPP_BASE_PATH = "/sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference"

  # Mapping for command-line options to profile keys (the actual amd epp argument)
  PROFILE_CLI_MAP = {
    "performance" => {
      short: "-a",
      long: "--max-performance",
      desc: "Prioritizes performance above power saving. CPU reaches higher clock speeds aggressively."
    },
    "balance_performance" => {
      short: "-z",
      long: "--balance-performance",
      desc: "Aims for a balance but leans towards performance. Default in many systems."
    },
    "balance_power" => {
      short: "-s",
      long: "--balance-powersave",
      desc: "Aims for a balance but leans towards power saving. More conservative clock speed increases."
    },
    "power" => {
      short: "-x",
      long: "--max-powersave",
      desc: "Strongly prioritizes power saving. Favors lower frequencies, may limit peak performance."
    }
  }.freeze

  # Define ANSI color codes
  COLORS = {
    "performance"         => "\e[31m", # Red
    "balance_performance" => "\e[33m", # Yellow
    "balance_power"       => "\e[34m", # Blue
    "power"               => "\e[32m", # Green
    "error"               => "\e[95m", # Bright Magenta (for file errors, not readable)
    "unknown"             => "\e[37m", # White/Gray (for EPP values read but not in PROFILE_CLI_MAP)
    "reset"               => "\e[0m"   # Reset color
  }.freeze

  def initialize
    # Initializes the manager, finding all CPU EPP paths
    # Sort for consistent ordering
    @epp_paths = Dir.glob(EPP_BASE_PATH).sort

    if @epp_paths.empty?
      warn "Error: No CPU energy preference files found under #{EPP_BASE_PATH.gsub('*', '<cpu_num>')}."
      warn "Error: Ensure your kernel supports AMD EPP and you have appropriate permissions."
      exit 1
    end

    # Parsed command-line options goes here
    @options = {}
  end

  # Main dispatch method based on parsed options
  def run(argv)
    parse_options(argv)

    case @options[:action]
    when :display_info
      display_info
    when :set_profile
      set_epp_profile(@options[:profile_key])
    # :display_help action is handled directly within parse_options by exiting.
    # If @options[:action] is nil here, it implies an issue with parse_options default logic,
    # but it should set :display_info by default if no other action is specified.
    else
      # This path should ideally not be reached if parse_options is comprehensive.
      warn "Internal Error: No action determined. Defaulting to info."
      display_info
    end
  end

  private
  # Private methods below this line
  # Populates @options, also handles -h, errors, and bad args
  def parse_options(argv)
    script_name = File.basename($PROGRAM_NAME)
    opt_parser = OptionParser.new do |opts|
      opts.banner = <<~BANNER
        #{script_name}: Manage AMD Energy Performance Preference (EPP) settings.
        Usage: #{script_name} [options]

        Profile options (select one):
      BANNER

      # Dynamically create options from PROFILE_CLI_MAP
      PROFILE_CLI_MAP.each do |profile_key, profile_data|
        opts.on(profile_data[:short], profile_data[:long], profile_data[:desc]) do
          @options[:action] = :set_profile
          @options[:profile_key] = profile_key
        end
      end

      opts.separator ""
      opts.separator "Other options:"

      opts.on_tail("-i", "--info", "Show the current state of AMD EPP.") do
        display_info
        exit
      end

      opts.on_tail("-h", "--help", "Show this message.") do
        puts opts
        puts ""
        puts "Additional notes:"
        puts "  To switch EPP profile without password, add the following line to sudoers file:"
        puts "  `[your_username] ALL=(root) NOPASSWD: /usr/bin/tee #{EPP_BASE_PATH}`"
        exit
      end
    end

    begin
      opt_parser.parse!(argv)
    rescue OptionParser::MissingArgument => e
      # Show help and bail out
      warn opt_parser
      exit 1
    rescue OptionParser::InvalidOption, OptionParser::InvalidArgument => e
      warn opt_parser
      exit 2
    end

    # Default action if the script is called wit no args
    @options[:action] ||= :display_info if @options.empty? || @options[:action].nil?
  end

  # Shows the current EPP information
  def display_info
    cpu_info_list = []

    # Process each EPP path to gather information
    @epp_paths.each do |filepath|
      cpu_num_match = filepath.match(%r{/cpu(\d+)/})
      unless cpu_num_match
        warn "Warning: Could not parse CPU number from path: #{filepath}"
        next # Skip if CPU number cannot be determined
      end
      cpu_num = cpu_num_match[1].to_i

      display_epp_value_base = "Error" # Default text for the EPP value
      color_key = "error"              # Default color key

      if File.readable?(filepath)
        begin
          # Read the raw EPP value from the file, strip whitespace, and convert to lowercase
          # to match keys in PROFILE_CLI_MAP.
          raw_epp_value = File.read(filepath).strip.downcase

          if PROFILE_CLI_MAP.key?(raw_epp_value)
            profile_data = PROFILE_CLI_MAP[raw_epp_value]
            # Get the long form and remove the leading "--"
            display_epp_value_base = profile_data[:long].sub(/^--/, '')
            color_key = raw_epp_value # Use the raw EPP value (e.g., "performance") as the key for COLORS
          else
            # If the EPP value from file is not in our map
            display_epp_value_base = "#{raw_epp_value} (Unknown)"
            color_key = "unknown"
          end
        rescue SystemCallError => e
          warn "Warning: Could not read EPP for #{filepath}: #{e.message}"
          display_epp_value_base = "Error reading"
        end
      else
        warn "Warning: EPP file #{filepath} is not readable."
        display_epp_value_base = "Not readable"
      end

      cpu_info_list << {
        cpu_num: cpu_num,                             # For sorting
        label: sprintf("CPU%02d", cpu_num),           # Formatted CPU label e.g., CPU00
        value_base: display_epp_value_base,           # The text to display for EPP state
        color_key: color_key                          # Key to look up in COLORS hash
      }
    end

    # Sort the gathered information by CPU number
    cpu_info_list.sort_by! { |info| info[:cpu_num] }

    # Determine the maximum width for CPU labels for alignment
    max_cpu_label_width = cpu_info_list.map { |info| info[:label].length }.max || 0
    puts "\nCurrent AMD EPP Status:"

    # Display the formatted and colored information
    cpu_info_list.each do |info|
      # Fetch the ANSI color code, defaulting to "unknown" color if key is somehow missing
      color_code = COLORS.fetch(info[:color_key], COLORS["unknown"])
      colored_value = "#{color_code}#{info[:value_base]}#{COLORS['reset']}"

      # Print in a tabular format: "CPUXX : EPP_STATE"
      # ljust ensures that all ":" characters align vertically.
      puts "#{info[:label].ljust(max_cpu_label_width)} : #{colored_value}"
    end
  end

  # Sets the EPP value for all CPU cores
  def set_epp_profile(epp_profile_key)
    unless PROFILE_CLI_MAP.key?(epp_profile_key)
      warn "Error: Invalid EPP profile key '#{epp_profile_key}'."
      warn "This is an internal error if triggered via command-line flags."
      return false # Should not happen if called via OptionParser
    end

    escaped_paths = @epp_paths.map { |p| Shellwords.escape(p) }.join(' ')
    command_str = "echo #{Shellwords.escape(epp_profile_key)} | sudo /usr/bin/tee #{escaped_paths}"

    puts "AMD EPP: Running (echo '#{epp_profile_key}' | sudo /usr/bin/tee) for #{@epp_paths.count} paths."
    success = system("#{command_str} > /dev/null 2>&1") # Redirect tee's usual stdout

    if success
      puts "AMD EPP: Successfully set value to #{epp_profile_key} for all detected CPU cores."
      return true
    else
      exit_status = $?.exitstatus
      epp_error = <<~EPP_ERROR
        Error: Failed to set EPP (exit status: #{exit_status}).
        Command attempted: echo '#{epp_profile_key}' | sudo /usr/bin/tee <paths>
        Possible reasons:
        - Incorrect sudo password entered (if prompted).
        - Lack of sudo permissions for '/usr/bin/tee' on EPP files.
        - EPP files are not writable even by root.
      EPP_ERROR

      warn epp_error
      return false
    end
  end
end # End AmdEppManager

# --- Script Entry Point ---
if __FILE__ == $PROGRAM_NAME
  manager = AmdEppManager.new

  # Pass a copy of ARGV because OptionParser.parse!
  # modifies the array that is passed.
  manager.run(ARGV.dup)
end
