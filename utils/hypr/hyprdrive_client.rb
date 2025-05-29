#!/usr/bin/env ruby
# hyprdrive.rb: Ruby wrappers to launch various hyprland stuff.
# Why Ruby? Because shell scripting basically sucks for parsing config
# frozen_string_literal: true

require_relative "../lib/lib_checker"

LibChecker.load(
  gems: %w[fileutils pathname yaml drb/drb],
  libs: %w[hyprdrive_config hyprdrive_socket],
  base: __dir__
)

class HyprdriveClient
  def initialize
    @config = load_configuration
    @socket_config = HyprdriveSocket::Config.load
    @daemon = connect_to_daemon
  end

  def execute(section, key, *args)
    return "Error: Could not connect to daemon" unless @daemon

    # Convert section and key from kebab-case to snake_case
    section = kebab_to_snake(section)
    key = kebab_to_snake(key)

    begin
      @daemon.perform_action(section, key, *args)
    rescue DRb::DRbConnError => e
      "Error: Lost connection to daemon - #{e.message}"
    rescue StandardError => e
      "Error: #{e.message}"
    end
  end

  private

  def load_configuration
    config_paths = [
      File.expand_path("~/.config/hyprdrive.yml"),
      File.expand_path("~/.config/hyprdrive.yaml"),
      File.expand_path("hyprdrive.yml", __dir__)
    ]

    config_path = config_paths.find { |path| File.exist?(path) }
    return nil unless config_path

    yaml_data = File.read(config_path)
    HyprdriveConfig.load_from_yaml(yaml_data)
  end

  def connect_to_daemon
    return nil unless @config

    begin
      DRb.start_service
      DRbObject.new_with_uri(@socket_config.uri)
    rescue DRb::DRbConnError => e
      warn "Error: Could not connect to daemon at #{@socket_config.uri}"
      warn "Make sure the daemon is running with: hyprdrive_daemon.rb start"
      nil
    end
  end

  def kebab_to_snake(str)
    str.to_s.gsub(/-/, '_')
  end
end

# Command line interface
if __FILE__ == $PROGRAM_NAME
  if ARGV.empty?
    puts "Usage  : #{$PROGRAM_NAME} <section> <key> [args...]"
    puts "Example: #{$PROGRAM_NAME} apps browser"
    puts "Example: #{$PROGRAM_NAME} actions volume-up"
    puts "Example: #{$PROGRAM_NAME} components app-launcher"
    exit 1
  end

  section = ARGV[0]
  key = ARGV[1]
  args = ARGV[2..]

  hyprdrive = HyprdriveClient.new
  result = hyprdrive.execute(section, key, *args)
  puts result
end
