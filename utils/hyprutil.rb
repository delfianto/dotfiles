#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'json'
require 'time'
require 'English' # Provides $CHILD_STATUS for checking command exit status

# Class to find the latest child process and interact with Hyprland
class HyprlandHelper
  DEFAULT_HYPRLAND_PID_CMD = "pidof -s Hyprland"
  HYPRCTL_CMD = 'hyprctl'

  def initialize(argv)
    @options = {
      parent_pid: nil,
      match_patterns: [],
      match_all: false,
      info_pid: nil,
      exec_command: nil,
      dispatch_command: nil
    }
    parse_options(argv)
    validate_options
  end

  def run
    if @options[:info_pid]
      print_client_info(@options[:info_pid])
    elsif @options[:exec_command] && @options[:dispatch_command]
      execute_and_dispatch
    else
      find_and_print_latest_pid
    end
  end

  private

  def parse_options(argv)
    OptionParser.new do |opts|
      opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
      opts.separator ""
      opts.separator "PID Tracking Options:"

      opts.on("--parent PID", Integer, "Track processes spawned by given parent PID") do |pid|
        @options[:parent_pid] = pid
      end

      opts.on("--match PATTERN", "Match app name or command line (can repeat)") do |pattern|
        @options[:match_patterns] << pattern
      end

      opts.on("--all", "Match all child processes (overrides --match)") do
        @options[:match_all] = true
      end

      opts.separator ""
      opts.separator "Hyprland Interaction Options:"

      opts.on("--info PID", Integer, "Get Hyprland client info for the specified PID") do |pid|
        @options[:info_pid] = pid
      end

      opts.on("--exec COMMAND", "Execute COMMAND and get its PID") do |cmd|
        @options[:exec_command] = cmd
      end

      opts.on("--dispatch DISPATCH", "Hyprctl dispatch command to run (requires --exec)") do |dispatch|
        @options[:dispatch_command] = dispatch
      end

      opts.separator ""
      opts.on_tail("-h", "--help", "Show this help message") do
        puts opts
        exit
      end
    end.parse!(argv)
  end

  def validate_options
    if @options[:exec_command] && !@options[:dispatch_command]
      warn "Error: --dispatch is required when using --exec."
      exit 1
    end
    if !@options[:exec_command] && @options[:dispatch_command]
      warn "Error: --exec is required when using --dispatch."
      exit 1
    end
    unless command_exists?(HYPRCTL_CMD)
       warn "Error: '#{HYPRCTL_CMD}' command not found. Please ensure Hyprland is running and hyprctl is in your PATH."
       exit 1
    end
  end

  def command_exists?(command)
    ENV['PATH'].split(File::PATH_SEPARATOR).any? { |path| File.exist?(File.join(path, command)) }
  end

  def get_hyprland_pid
    pid_str = `#{DEFAULT_HYPRLAND_PID_CMD}`.strip
    if $CHILD_STATUS.success? && !pid_str.empty?
      pid_str.to_i
    else
      warn "Error: Could not determine Hyprland PID using '#{DEFAULT_HYPRLAND_PID_CMD}'. Use --parent PID."
      exit 1
    end
  end

  # Recursively finds all descendant PIDs
  def get_descendants(parent_pid)
    descendants = []
    # Use ps to find immediate children
    child_pids_str = `ps -o pid --no-headers --ppid #{parent_pid}`

    return descendants unless $CHILD_STATUS.success?

    child_pids = child_pids_str.lines.map { |line| line.strip.to_i }

    child_pids.each do |child_pid|
      descendants << child_pid
      descendants.concat(get_descendants(child_pid)) # Recurse
    end

    descendants
  end

  # Reads process information from /proc
  def get_process_info(pid)
    proc_dir = "/proc/#{pid}"
    return nil unless File.directory?(proc_dir) && File.readable?(proc_dir)

    begin
      cmd_name = File.read(File.join(proc_dir, 'comm')).strip
      # cmdline uses null bytes as separators
      cmdline = File.read(File.join(proc_dir, 'cmdline')).split("\0").join(' ').strip
      # Use mtime as an approximation for start time, similar to stat -c %Y /proc/pid
      start_time = File.stat(proc_dir).mtime.to_i
      { pid: pid, cmd_name: cmd_name, cmdline: cmdline, start_time: start_time }
    rescue Errno::ENOENT, Errno::ESRCH # Process might disappear between checks
      nil
    rescue Errno::EACCES # Permission denied
        warn "Warning: Permission denied reading info for PID #{pid}"
        nil
    end
  end

  def process_matches?(info)
    return false unless info # Skip if info couldn't be read

    return true if @options[:match_all]
    return true if @options[:match_patterns].empty? # Default: match if no patterns specified

    @options[:match_patterns].any? do |pattern|
      info[:cmd_name].include?(pattern) || info[:cmdline].include?(pattern)
    end
  end

  def find_and_print_latest_pid
    target_parent_pid = @options[:parent_pid] || get_hyprland_pid
    descendants = get_descendants(target_parent_pid)

    latest_process = nil

    descendants.each do |pid|
      info = get_process_info(pid)
      next unless info && process_matches?(info)

      if latest_process.nil? || info[:start_time] > latest_process[:start_time]
        latest_process = info
      end
    end

    if latest_process
      puts "Latest matched process:"
      puts "  PID: #{latest_process[:pid]}"
      puts "  Started: #{Time.at(latest_process[:start_time])}"
      puts "  Command: #{latest_process[:cmdline]}"
      puts "  Comm Name: #{latest_process[:cmd_name]}"
    else
      puts "No matching child process found under PID #{target_parent_pid}"
    end
  end

  def get_hyprland_client_info(pid)
    begin
      json_output = `#{HYPRCTL_CMD} clients -j`
      unless $CHILD_STATUS.success?
        warn "Error running '#{HYPRCTL_CMD} clients -j'. Exit status: #{$CHILD_STATUS.exitstatus}"
        return nil
      end
      clients = JSON.parse(json_output)
      clients.find { |client| client['pid'] == pid }
    rescue JSON::ParserError => e
      warn "Error parsing JSON output from hyprctl: #{e.message}"
      nil
    rescue Errno::ENOENT
        warn "Error: '#{HYPRCTL_CMD}' command not found."
        exit 1 # Exit here as hyprctl is essential for this function
    end
  end

  def print_client_info(pid)
    info = get_hyprland_client_info(pid)
    if info
      puts "Hyprland client info for PID #{pid}:"
      info.each do |key, value|
        puts "  #{key}: #{value}"
      end
    else
      puts "No Hyprland client found with PID #{pid}."
    end
  end

  def execute_and_dispatch
    puts "Executing: #{@options[:exec_command]}"
    begin
      # Spawn the process without waiting for it to finish
      pid = Process.spawn(@options[:exec_command], err: :out, out: '/dev/null') # Redirect output unless needed
      puts "Spawned process with PID: #{pid}"
      # Give the application a moment to potentially register with Hyprland
      sleep 0.5 # Adjust sleep time if needed

      # Find the specific client window associated with this PID.
      # Hyprland might take a moment to map the window. Retry briefly.
      client_info = nil
      retries = 5
      while retries > 0 && client_info.nil?
        client_info = get_hyprland_client_info(pid)
        break if client_info
        sleep 0.2
        retries -= 1
      end

      unless client_info
          warn "Warning: Could not find Hyprland client info for PID #{pid} after spawning."
          warn "Dispatch command might target the wrong window if multiple instances exist."
          # Proceed with dispatch using PID anyway, as some commands might work
      end

      dispatch_cmd_formatted = @options[:dispatch_command].gsub('%PID%', pid.to_s)
      # Example of how you might use client info if needed:
      # dispatch_cmd_formatted = @options[:dispatch_command].gsub('%ADDRESS%', client_info['address']) if client_info

      puts "Running: #{HYPRCTL_CMD} dispatch #{dispatch_cmd_formatted}"
      system("#{HYPRCTL_CMD} dispatch #{dispatch_cmd_formatted}")
      unless $CHILD_STATUS.success?
          warn "Warning: hyprctl dispatch command failed. Exit status: #{$CHILD_STATUS.exitstatus}"
      end

    rescue Errno::ENOENT => e
      warn "Error executing command '#{@options[:exec_command]}': #{e.message}"
      exit 1
    rescue StandardError => e
      warn "An unexpected error occurred during execution/dispatch: #{e.message}"
      exit 1
    end
  end
end

# --- Main Execution ---
if $PROGRAM_NAME == __FILE__
  begin
    tracker = HyprlandHelper.new(ARGV)
    tracker.run
  rescue OptionParser::MissingArgument => e
    warn "Error: #{e.message}"
    warn "Run with --help for usage information."
    exit 1
  rescue OptionParser::InvalidOption => e
     warn "Error: #{e.message}"
     warn "Run with --help for usage information."
     exit 1
  rescue => e # Catch other potential errors during initialization
    warn "An unexpected error occurred: #{e.message}"
    warn e.backtrace.join("\n\t")
    exit 1
  end
end
