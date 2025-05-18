#!/usr/bin/env ruby
# amd_epp_set.rb: Manage AMD Energy Performance Preference (EPP) settings.
# frozen_string_literal: true

require_relative "lib_runner"

# --- Application logic implementations ---
class AmdEppMgr
  EPP_BASE_PATH = "/sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference"

  def initialize
    # Initializes the manager, finding all CPU EPP paths
    @epp_paths = Dir.glob(EPP_BASE_PATH).sort
    raise ArgumentError, "Error: No CPU energy preference files found." if @epp_paths.empty?
  end

  def apply_profile(profile_key)
    puts "Applying EPP setting: #{profile_key}"
    paths = @epp_paths.map { |p| Shellwords.escape(p) }.join("  ")

    puts "AMD EPP: Running (echo '#{profile_key}' | sudo /usr/bin/tee) for #{@epp_paths.count} paths."
    command = "echo #{Shellwords.escape(profile_key)} | sudo /usr/bin/tee #{paths}"
    stdout, stderr, status = Open3.capture3(command)

    if status.success?
      puts "AMD EPP: Successfully set value to #{profile_key} for all detected CPU cores."
    else
      epp_error = <<~EPP_ERROR
        Error: Failed to set EPP (exit status: #{status.exitstatus}).
        Command attempted: #{command}
        Stdout: #{stdout}
        Stderr: #{stderr}
        Possible reasons:
          - Incorrect sudo password entered (if prompted).
          - Lack of sudo permissions for '/usr/bin/tee' on EPP files.
          - EPP files are not writable even by root.
      EPP_ERROR
      warn epp_error
      exit status.exitstatus
    end
  end

  def read_profile
    cpu_info_list = []
    @epp_paths.each do |path|
      cpu_num_match = path.match(%r{/cpu(\d+)/})
      cpu_num = cpu_num_match[1].to_i

      epp_value = File.read(path).strip
      cpu_info_list << "#{format('CPU%02d', cpu_num)}: #{epp_value}"
    end

    cpu_info_string = cpu_info_list.sort.join("\n")
    stdout, stderr, status = Open3.capture3("column", stdin_data: cpu_info_string)

    if status.success?
      puts stdout
    else
      warn "Error formatting output with 'column':"
      warn stderr
      puts cpu_info_string # Fallback to unformatted output
    end
  end

  # Class AmdEppMgr
end

# --- Configure the CLI using class-level DSL ---
class AmdEppCLI < CLIRunner
  # Define the available performance profiles and their descriptions.
  PROFILE_MAP = {
    bal_performance: {
      profile_key: "balance_performance",
      desc: "Aims for a balance but leans towards performance. Default in many systems."
    }.freeze,
    max_performance: {
      profile_key: "performance",
      desc: "Prioritizes performance above power saving. CPU reaches higher clock speeds aggressively."
    }.freeze,
    bal_powersave: {
      profile_key: "balance_power",
      desc: "Aims for a balance but leans towards power saving. More conservative clock speed increases."
    }.freeze,
    max_powersave: {
      profile_key: "power",
      desc: "Strongly prioritizes power saving. Favors lower frequencies, may limit peak performance."
    }.freeze
  }.freeze

  # Instance initialization
  def initialize
    super(app_name: "amd_epp_tool", version: "1.1.0") # Call parent initializer
    @epp_mgr = AmdEppMgr.new
  end

  # Define options
  option :profile,
         type: :string,
         short: "-p",
         long: "--profile",
         desc: "Set the performance profile."

  option :read,
         type: :boolean,
         short: "-r",
         long: "--read",
         desc: "Read the current EPP value for all CPUs."

  # Define custom help sections
  help_section "Available AMD Performance Profiles" do
    lines = []
    max_len = PROFILE_MAP.keys.map(&:length).max || 0

    PROFILE_MAP.each do |name, details|
      profile_name = to_kebab(name.to_s)
      lines << "  #{profile_name.ljust(max_len)}  #{details[:desc]}"
    end

    lines.join("\n")
  end

  # This is the main action method
  def execute
    if option_present?(:profile)
      apply_profile
    elsif option_present?(:read)
      read_profile
    end
  end

  private # All methods defined after this are private

  def to_kebab(str)
    str.gsub("_", "-")
  end

  def to_snake(str)
    str.gsub("-", "_")
  end

  def apply_profile
    profile_name = option_value(:profile)
    valid_profiles = PROFILE_MAP.keys.map do |key|
      to_kebab(key.to_s)
    end

    # Check if the profile name exist in mapping
    if valid_profiles.include?(profile_name)
      sym = to_snake(profile_name).to_sym
      selected = PROFILE_MAP[sym]
      @epp_mgr.apply_profile(selected[:profile_key])
    else
      warn "Invalid profile name '#{profile_name}'."
      warn "Available profiles are: #{valid_profiles.join(', ')}."
      exit 1
    end
  end

  def read_profile
    @epp_mgr.read_profile
  end

  # Class AmdEppCLI
end

AmdEppCLI.start(ARGV) if __FILE__ == $PROGRAM_NAME
