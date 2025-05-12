#!/usr/bin/env ruby
require 'yaml'
require 'json'
require 'optparse'
require 'open3'
require 'shellwords'
require 'colorize'

class HyprStartup
  LEVELS = {
    debug: :cyan,
    info:  :green,
    warn:  :yellow,
    error: :red
  }

  def initialize
    @options = parse_options
    @debug   = @options[:debug]
    @workspace_arg = @options[:workspace]
    load_config
  end

  def run
    log(:info, "Starting Hypr startup flow")
    smart_sleep(@config['settings']['initial_delay'], @config['settings']['delay_jitter'])

    if @workspace_arg
      log(:info, "Running specific workspace: #{@workspace_arg}")
      run_workspace(@workspace_arg)
    else
      log(:info, "No workspace specified. Running all workspaces")
      run_all_workspaces
    end

    log(:info, "Hypr startup flow completed")
  end

  private

  def parse_options
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: #{__FILE__} [options] [workspace]"
      opts.on('--debug', 'Enable debug (dry-run) mode') { options[:debug] = true }
      opts.on('-h', '--help', 'Show help') { puts opts; exit }
    end.parse!(into: options)
    options[:workspace] = ARGV.shift
    options
  end

  def load_config
    path = ENV['HYPR_STARTUP_FLOW'] || File.expand_path('~/.config/hypr/conf/autostart.yaml')
    raise "Config not found: #{path}" unless File.exist?(path)
    @config = YAML.load_file(path)
    # Set defaults
    @config['settings'] ||= {}
    %w[initial_delay inter_desktop_delay inter_app_delay delay_jitter].each do |key|
      @config['settings'][key] ||= default_value(key)
    end
    @config['workspaces'] ||= []
  rescue => e
    log(:error, e.message)
    exit 1
  end

  def default_value(key)
    case key
    when 'initial_delay'          then 1.0
    when 'inter_desktop_delay'    then 0.5
    when 'inter_app_delay'        then 0.5
    when 'delay_jitter'           then 0.2
    end
  end

  def log(level, msg)
    lvl = level.to_sym
    name = File.basename(__FILE__)[0,15].ljust(15)
    pid  = Process.pid.to_s.ljust(6)
    time = Time.now.strftime('%Y-%m-%d:%H:%M:%S')
    color = LEVELS[lvl] || :default
    tag   = lvl.to_s.upcase.ljust(5)
    puts "[#{name}:#{pid}:#{time}][#{tag.colorize(color)}] #{msg}"
  end

  def smart_sleep(base, jitter)
    delay = base + rand * jitter
    if @debug
      log(:debug, "Simulating sleep for #{'%.2f' % delay}s (base=#{base}, jitter=#{jitter})")
    else
      log(:debug, "Sleeping for #{'%.2f' % delay}s (base=#{base}, jitter=#{jitter})")
      sleep(delay)
    end
  end

  def run_all_workspaces
    @config['workspaces'].each do |ws|
      run_workspace(ws['workspace'])
    end
  end

  def run_workspace(name)
    ws = find_workspace(name)
    unless ws
      log(:warn, "Workspace not found: #{name}")
      return
    end
    log(:info, "Initializing workspace: #{ws['workspace']}")
    run_hooks(ws, 'before_each')
    ws['commands'].to_a.each do |cmd|
      exec = cmd['exec']
      args = cmd['args'] || []
      if exec.to_s.empty?
        log(:warn, "Skipping empty command in workspace #{ws['workspace']}")
      else
        expand_and_run(exec, args, ws['workspace'])
      end
    end
    run_hooks(ws, 'after_each')
  end

  def find_workspace(name)
    @config['workspaces'].find { |w| w['workspace'].to_s == name.to_s }
  end

  def run_hooks(ws, hook)
    hook_conf = ws.dig('hooks', hook)
    return unless hook_conf && hook_conf['exec']
    log(:info, "Running #{hook} hook for workspace #{ws['workspace']}")
    expand_and_run(hook_conf['exec'], hook_conf['args'] || [], ws['workspace'])
  end

  def expand_and_run(exec, args, workspace)
    args = args.map { |a| Shellwords.shellexpand(a) }
    cmd = ([exec] + args).join(' ')
    log(:info, "Executing: #{cmd}")
    if @debug
      log(:debug, "Dry-run, not executing command")
    else
      pid = spawn(exec, *args)
      log(:info, "Spawned PID: #{pid}")
      _, status = Process.wait2(pid)
      move_window_to_workspace(pid, workspace)
    end
    smart_sleep(@config['settings']['inter_app_delay'], @config['settings']['delay_jitter'])
  end

  def move_window_to_workspace(pid, workspace)
    log(:info, "Moving window of PID #{pid} to workspace #{workspace}")
    30.times do
      out, _ = Open3.capture2('hyprctl', 'clients', '-j')
      clients = JSON.parse(out)
      win = clients.find { |c| c['pid'] == pid }
      if win && win['address']
        system('hyprctl', 'dispatch', "movetoworkspace #{workspace},address:#{win['address']}")
        return
      end
      sleep(0.2)
    end
    log(:warn, "Window for PID #{pid} not found after retries")
  end
end

# Execute
HyprStartup.new.run
