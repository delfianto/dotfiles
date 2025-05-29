#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/lib_checker"

LibChecker.load(
  gems: %w[daemons drb/drb yaml],
  libs: %w[hyprdrive_config hyprdrive_socket],
  base: __dir__
)

# Define blacklisted commands (case-insensitive).
BLACKLISTED_COMMANDS = %w[
  rm dd sudo pkexec polkit mkfs fdisk
  parted shred systemctl chown chmod
].map(&:downcase).freeze

# Default configuration file path
DEFAULT_CONFIG_PATH = File.expand_path("hyprdrive.yml")

# User defined configuration file path
USER_CONFIG_DIR = File.expand_path("~/.config")
USER_CONFIG_FILES = [
  File.join(USER_CONFIG_DIR, "hyprdrive.yml"),
  File.join(USER_CONFIG_DIR, "hyprdrive.yaml")
].freeze

# This class will be exposed via DRb. Its methods will be callable by clients.
class HyprdriveDaemon
  def initialize
    find_config_file = lambda do
      # Check for user-supplied configuration files first
      user_config_path = USER_CONFIG_FILES.find { |file_path| File.exist?(file_path) }

      if user_config_path
        puts "Daemon: Using user configuration file: #{user_config_path}"
        user_config_path
      else
        puts "Daemon: User configuration not found, using default: #{DEFAULT_CONFIG_PATH}"
        DEFAULT_CONFIG_PATH
      end
    end

    @config_yaml_path = find_config_file.call
    @config = load_configuration
    puts "Daemon: Initialization complete."
  end

  def load_configuration
    puts "Daemon: Loading configuration from #{@config_yaml_path}..."
    yaml_data = File.read(@config_yaml_path)
    HyprdriveConfig.load_from_yaml(yaml_data)
  rescue StandardError => e
    warn "Daemon: Failed to load configuration: #{e.message}"
    nil # Or a default empty config
  end

  def reload_config
    @config = load_configuration
    if @config
      "Daemon: Configuration reloaded successfully."
    else
      "Daemon: Failed to reload configuration. Check daemon logs."
    end
  end

  # Client will call this method
  def perform_action(section_name, key_name, *_args)
    return "Daemon: Configuration not loaded." unless @config
    return "Daemon: Invalid section or key." unless section_name && key_name

    section_sym = section_name.to_sym
    key_sym = key_name.to_sym

    section_object = get_section(section_sym)
    return "Daemon: Unknown section '#{section_name}'." unless section_object

    command = get_command(section_object, key_sym)
    execute_command(section_name, key_name, command)
  end

  private

  def get_section(section_sym)
    @config.hyprland.public_send(section_sym) if @config.hyprland.respond_to?(section_sym)
  end

  def get_command(section_object, key_sym)
    # Try direct attribute access first
    return section_object.public_send(key_sym) if section_object.respond_to?(key_sym)

    # Fallback to checking custom sections
    custom_attr_name = determine_custom_attribute_name(section_object)
    return nil unless custom_attr_name && section_object.respond_to?(custom_attr_name)

    custom_hash = section_object.public_send(custom_attr_name)
    custom_hash[key_sym] if custom_hash.is_a?(Hash)
  end

  def determine_custom_attribute_name(section_object)
    case section_object
    when HyprdriveConfig::AppsConfig, HyprdriveConfig::ActionsConfig
      :custom_actions
    when HyprdriveConfig::ComponentsConfig
      :custom_components
    end
  end

  def execute_command(section_name, key_name, command)
    if command.nil?
      return "Daemon: Action '#{key_name}' not found or has no command in section '#{section_name}'."
    end

    if command == "none"
      return "Daemon: Action '#{key_name}' is configured as 'none'."
    end

    puts "Daemon: Action '#{key_name}' in section '#{section_name}' -> '#{command}'"

    if command_blacklisted?(command.to_s)
      warn "Daemon: Attempt to execute blacklisted command: '#{command}' " \
           "from section '#{section_name}', key '#{key_name}'"
      return "Daemon: Command '#{command}' is blacklisted and cannot be executed."
    end

    "Daemon: Action '#{key_name}' -> Value: #{command.inspect}"
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
