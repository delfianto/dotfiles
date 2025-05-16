#!/usr/bin/env ruby
# frozen_string_literal: true
# amd_epp.rb ~ Manage AMD Energy Performance Preference (EPP) settings.

require_relative 'lib_runner'

# --- Application logic ---
class AmdEppMgr
  def apply_profile(epp_arg)
    puts "Applying EPP setting: #{epp_arg}"
  end
end

# --- Configure the CLI using class-level DSL ---
class AmdEppCLI < CLIRunner
  # Define the available performance profiles and their descriptions.
  PROFILE_MAP = {
    "max-performance" => {
      epp_arg: "performance",
      desc: "Prioritizes performance above power saving. CPU reaches higher clock speeds aggressively."
    },
    "balance-performance" => {
      epp_arg: "balance_performance",
      desc: "Aims for a balance but leans towards performance. Default in many systems."
    },
    "balance-powersave" => {
      epp_arg: "balance_power",
      desc: "Aims for a balance but leans towards power saving. More conservative clock speed increases."
    },
    "max-powersave" => {
      epp_arg: "power",
      desc: "Strongly prioritizes power saving. Favors lower frequencies, may limit peak performance."
    }
  }.freeze

  # Define options
  option :profile,
    type: :string,
    short: '-p',
    long: '--profile',
    desc: 'Set the performance profile.'

  # Define custom help sections
  help_section "Available AMD Performance Profiles" do
    # This block is instance_eval'd in the context of AmdEppCLI instance.
    # It can access instance methods or variables if needed.
    lines = []
    max_len = PROFILE_MAP.keys.map(&:length).max || 0
    PROFILE_MAP.each do |name, details|
      lines << "   #{name.ljust(max_len)}  #{details[:desc]}"
    end
    lines.join("\n")
  end

  # --- Instance Initialization and Main Logic ---
  def initialize
    super(app_name: "amd_epp_tool", version: "1.1.0") # Call parent initializer
    @amd_epp_mgr = AmdEppMgr.new
  end

  # This is the main action method (default is :execute)
  # It has access to `parsed_options` (Slop::Result) and `remaining_args` (Array)
  # which are instance variables set by the base class.
  def execute
    # Check if :profile option was given
    if parsed_options.profile?
      profile_name = parsed_options[:profile]

      # Check if the profile name exist in mapping
      if PROFILE_MAP.key?(profile_name)
        selected_profile_details = PROFILE_MAP[profile_name]
        puts "Selected profile: #{profile_name}"
        @amd_epp_mgr.apply_profile(selected_profile_details[:epp_arg])
      else
        error_msg = "Invalid profile name '#{profile_name}'.\n" \
                    "Available profiles are: #{PROFILE_MAP.keys.join(', ')}.\n"
        print_help_and_exit(1, error_msg)
      end
    else
      # This means --profile was not given.
      # --list-profiles would have exited if used.
      # --help or --version would have exited.
      if remaining_args.any?
        print_help_and_exit(1, "Unknown arguments: #{remaining_args.join(' ')}")
      else
        # No profile, no unknown args -> user likely needs help or forgot the main option
        print_help_and_exit(1, "No profile specified. Please use the --profile option or --help.")
      end
    end
  end
# End of AmdEppCLI
end

if __FILE__ == $PROGRAM_NAME
  AmdEppCLI.start(ARGV)
end
