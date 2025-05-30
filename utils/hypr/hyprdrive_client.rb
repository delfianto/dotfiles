#!/usr/bin/env ruby
# hyprdrive.rb: Ruby wrappers to launch various hyprland stuff.
# Why Ruby? Because shell scripting basically sucks for parsing config
# frozen_string_literal: true

require_relative "../lib/lib_checker"

LibChecker.load(
  gems: %w[drb/drb],
  libs: %w[hyprdrive_socket],
  base: __dir__
)

class Hyprdrive
  def initialize
    @socket_config = HyprdriveSocket::Config.load
    @daemon = connect_to_daemon
  end

  def execute(section, key, *args)
    return "Error: Could not connect to daemon" unless @daemon

    # Convert section and key from kebab-case to snake_case
    section = kebab_to_snake(section)
    key = kebab_to_snake(key)

    begin
      result = @daemon.perform_action(section, key, *args)
      if result =~ /PID: (\d+)/
        # Return both the message and the PID
        { message: result, pid: $1.to_i }
      else
        { message: result }
      end
    rescue DRb::DRbConnError => e
      "Error: Lost connection to daemon - #{e.message}"
    rescue StandardError => e
      "Error: #{e.message}"
    end
  end

  def list_processes
    return "Error: Could not connect to daemon" unless @daemon
    @daemon.get_running_processes
  end

  def kill_process(pid)
    return "Error: Could not connect to daemon" unless @daemon
    @daemon.kill_process(pid)
  end

  private

  def connect_to_daemon
    DRb.start_service
    DRbObject.new_with_uri(@socket_config.uri)
  rescue DRb::DRbConnError => _e
    warn "Error: Could not connect to daemon at #{@socket_config.uri}"
    warn "Make sure the daemon is running with: hyprdrive_daemon.rb start"
    nil
  end

  def kebab_to_snake(str)
    str.to_s.gsub(/-/, "_")
  end
end

# Command line interface
if __FILE__ == $PROGRAM_NAME
  if ARGV.empty?
    puts "Usage: #{$PROGRAM_NAME} <command> [args...]"
    puts "\nCommands:"
    puts "  <section> <key> [args...]  Execute a command (e.g., 'apps browser')"
    puts "  list                       List running processes"
    puts "  kill <pid>                 Kill a specific process"
    puts "\nExamples:"
    puts "  #{$PROGRAM_NAME} apps browser"
    puts "  #{$PROGRAM_NAME} actions volume-up"
    puts "  #{$PROGRAM_NAME} list"
    puts "  #{$PROGRAM_NAME} kill 12345"
    exit 1
  end

  hyprdrive = Hyprdrive.new

  case ARGV[0]
  when "list"
    processes = hyprdrive.list_processes
    if processes.is_a?(Array) && !processes.empty?
      puts "Running processes:"
      processes.each do |proc|
        puts "PID: #{proc[:pid]}"
        puts "  Command: #{proc[:command]} #{proc[:args].join(' ')}"
        puts "  Started: #{proc[:start_time]}"
        puts "  Runtime: #{proc[:runtime].round(1)} seconds"
        puts "  Section: #{proc[:section]}"
        puts "  Key: #{proc[:key]}"
        puts "---"
      end
    else
      puts "No processes running"
    end
  when "kill"
    if ARGV[1].nil?
      puts "Error: No PID specified"
      exit 1
    end
    result = hyprdrive.kill_process(ARGV[1].to_i)
    puts result
  else
    section = ARGV[0]
    key = ARGV[1]
    args = ARGV[2..]

    if key.nil?
      puts "Error: No key specified for section '#{section}'"
      exit 1
    end

    result = hyprdrive.execute(section, key, *args)

    if result.is_a?(Hash)
      puts result[:message]
      puts "Process ID: #{result[:pid]}" if result[:pid]
    else
      puts result
    end
  end
end
