#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/lib_checker"

LibChecker.load(
  gems: %w[daemons drb/drb yaml fileutils],
  libs: %w[hyprdrive_config hyprdrive_socket],
  base: __dir__
)

# Define blacklisted commands (case-insensitive).
BLACKLISTED_COMMANDS = %w[
  rm dd sudo pkexec polkit mkfs fdisk
  parted shred systemctl chown chmod
].map(&:downcase).freeze

# Configuration path priority
CONFIG_PATHS = [
  File.expand_path("~/.config/hyprdrive.yml"),
  File.expand_path("~/.config/hyprdrive.yaml"),
  File.expand_path("hyprdrive.yml")
].freeze

# This class will be exposed via DRb. Its methods will be callable by clients.
class HyprdriveDaemon
  def initialize
    find_config_file = lambda do
      config_path = CONFIG_PATHS.find { |file_path| File.exist?(file_path) }
      raise "Missing hyprdrive configuration!" unless config_path

      puts "Daemon: Using user configuration file: #{config_path}"
      config_path
    end

    @yaml_path = find_config_file.call
    @config = load_config
    @process_list = {}
    puts "Daemon: Initialization complete."
  end

  def load_config
    puts "Daemon: Loading configuration from #{@yaml_path}..."
    yaml_data = File.read(@yaml_path)
    HyprdriveConfig.load_from_yaml(yaml_data)
  rescue StandardError => e
    warn "Daemon: Failed to load configuration: #{e.message}"
    nil # Or a default empty config
  end

  def reload_config
    @config = load_config
    if @config
      "Daemon: Configuration reloaded successfully."
    else
      "Daemon: Failed to reload configuration. Check daemon logs."
    end
  end

  # Public methods for DRb
  def perform_action(section_name, key_name, *args)
    return "Daemon: Configuration not loaded." unless @config
    return "Daemon: Invalid section or key." unless section_name && key_name

    section_sym = section_name.to_sym
    key_sym = key_name.to_sym

    section = @config.hyprland.public_send(section_sym) if @config.hyprland.respond_to?(section_sym)
    return "Daemon: Unknown section '#{section_name}'." unless section

    command_builder = lambda do
      attr = case section
             when HyprdriveConfig::AppsConfig, HyprdriveConfig::ActionsConfig
               :custom_actions
             when HyprdriveConfig::ComponentsConfig
               :custom_components
             end

      # Try direct attribute access first
      return section.public_send(key_sym) if section.respond_to?(key_sym)

      # Fallback to checking custom sections
      return nil unless attr && section.respond_to?(attr)

      custom_hash = section.public_send(attr)
      custom_hash[key_sym] if custom_hash.is_a?(Hash)
    end

    command = command_builder.call
    execute_command(section_name, key_name, command, *args)
  end

  def process_list
    @process_list.map do |pid, info|
      {
        pid: pid,
        command: info[:command],
        args: info[:args],
        start_time: info[:start_time],
        section: info[:section],
        key: info[:key],
        runtime: Time.now - info[:start_time]
      }
    end
  end

  def kill_process(pid)
    return "Daemon: Process #{pid} not found" unless @process_list.key?(pid)

    begin
      Process.kill("TERM", pid)
      sleep 1
      Process.kill("KILL", pid) if Process.wait(pid, Process::WNOHANG).nil?

      @process_list.delete(pid)
      "Daemon: Process #{pid} terminated"
    rescue StandardError => e
      "Daemon: Error terminating process #{pid}: #{e.message}"
    end
  end

  private

  def execute_command(section_name, key_name, command, *args)
    return "Daemon: Action '#{key_name}' not found in section '#{section_name}'." if command.nil?
    return "Daemon: Action '#{key_name}' is configured as 'none'." if command == "none"

    puts "Daemon: Action '#{key_name}' in section '#{section_name}' -> '#{command}'"

    if command_blacklisted?(command.to_s)
      warn "Daemon: Attempt to execute blacklisted command: '#{command}' " \
           "from section '#{section_name}', key '#{key_name}'"

      return "Daemon: Command '#{command}' is blacklisted and cannot be executed."
    end

    # Parse command and arguments
    cmd_parts = command.split
    base_cmd = cmd_parts.first
    cmd_args = cmd_parts[1..] + args

    # Execute the command
    begin
      pid = spawn_command(base_cmd, *cmd_args)
      if pid
        @process_list[pid] = {
          command: command,
          args: cmd_args,
          start_time: Time.now,
          section: section_name,
          key: key_name
        }
        "Daemon: Action '#{key_name}' started (PID: #{pid})"
      else
        "Daemon: Failed to start action '#{key_name}'"
      end
    rescue StandardError => e
      "Daemon: Error executing action '#{key_name}': #{e.message}"
    end
  end

  def spawn_command(cmd, *args)
    # Create a unique identifier for this process
    process_id = "#{cmd}_#{Time.now.to_i}"

    # Prepare the command with arguments
    full_cmd = [cmd, *args].join(" ")

    # Spawn the process
    pid = Process.spawn(full_cmd, {
      pgroup      => true, # Create new process group
      %i[out err] => "/tmp/hyprdrive_#{process_id}.log" # Log output
    })

    # Start a thread to monitor the process
    Thread.new do
      Process.wait(pid)
      @process_list.delete(pid)
      # Clean up log file
      FileUtils.rm_f("/tmp/hyprdrive_#{process_id}.log")
    rescue StandardError => e
      warn "Daemon: Error monitoring process #{pid}: #{e.message}"
    end

    pid
  end

  # Helper method to check if a command string contains a blacklisted command.
  def command_blacklisted?(command_string)
    return false if command_string.nil? || command_string.strip.empty?

    normalized_command_string = command_string.to_s.downcase
    first_word = normalized_command_string.strip.split.first
    return false unless first_word

    command_name = File.basename(first_word).downcase

    BLACKLISTED_COMMANDS.include?(command_name) ||
      BLACKLISTED_COMMANDS.any? { |blacklisted_cmd| normalized_command_string.include?(blacklisted_cmd) }
  end
end

# Daemon control options
daemon_options = {
  app_name: "hyprdrive",
  dir_mode: :normal, # Store pid files in :dir
  dir: "/tmp",       # Working directory for the daemon process
  log_output: true,  # Log stdout/stderr to a file
  multiple: false,   # Ensure only one instance runs
  backtrace: true    # Log backtrace on error (for debugging purpose)
}

# This block runs as the daemonized process
Daemons.run_proc("hyprdrive", daemon_options) do
  hyprdrive_service = HyprdriveDaemon.new
  socket_config = HyprdriveSocket::Config.load
  puts "Daemon: Service initialized."

  shutdown_requested = false

  at_exit do
    puts "Daemon: Stopping DRb service..."
    DRb.stop_service if DRb.primary_server
  end

  Signal.trap("INT") do
    puts "\nDaemon: SIGINT received, initiating graceful shutdown..."
    shutdown_requested = true
  end

  Signal.trap("TERM") do
    puts "Daemon: SIGTERM received, initiating graceful shutdown..."
    shutdown_requested = true
  end

  begin
    puts "Daemon: Starting DRb service..."
    DRb.start_service(socket_config.uri, hyprdrive_service)
    puts "Daemon: DRb service started at #{socket_config.uri}"

    loop do
      if shutdown_requested
        puts "Daemon: Shutdown flag detected in main loop. Initiating DRb stop."
        DRb.stop_service
        break
      end

      unless DRb.thread&.alive?
        puts "Daemon: DRb thread is no longer alive or not started. Exiting loop."
        DRb.stop_service if DRb.primary_server && !shutdown_requested
        break
      end

      DRb.thread.join(0.5)
    end

    puts "Daemon: DRb processing loop finished."

  rescue Interrupt
    puts "Daemon: Interrupt caught directly in main loop. Ensuring DRb stop."
    DRb.stop_service if DRb.primary_server
  rescue SystemExit
    puts "Daemon: SystemExit caught. Allowing shutdown procedure."
    raise
  rescue StandardError => e
    warn "Daemon: An unexpected error occurred in the main DRb loop: #{e.message}"
    warn e.backtrace.join("\n") if daemon_options[:backtrace]
    DRb.stop_service if DRb.primary_server
  ensure
    DRb.stop_service if DRb.primary_server
  end
end
