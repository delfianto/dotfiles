# frozen_string_literal: true
# shell_configurator.rb - A simple DSL for configuring shell environments.

require 'fileutils'
require 'rbconfig'

class ShellConfigurator
  def initialize
    @commands = []
    @env_updates = {}
    @alias_updates = {}
    @path_updates = []
  end

  def set_alias(name, command)
    @alias_updates[name] = command
  end

  def set_alias_on_exist(name, command)
    executable = command.split.first # Extract the first word as the executable
    @alias_updates[name] = command if executable_exists?(executable) && !same_command?(command, executable)
  end

  def set_env(name, value)
    @env_updates[name] = value
  end

  def set_prompt(new_prompt)
    @commands << "PS1='#{new_prompt}'"
  end

  def mod_path(directory, position: :before)
    @path_updates << { directory: directory, position: position }
  end

  def check_executable(executable, &block)
    if executable_exists?(executable)
      instance_eval(&block) if block_given?
    end
  end

  def check_readable_dir(directory, &block)
    if Dir.exist?(directory) && File.readable?(directory)
      instance_eval(&block) if block_given?
    end
  end

  def check_writable_dir(directory, &block)
    if Dir.exist?(directory) && File.writable?(directory)
      instance_eval(&block) if block_given?
    end
  end

  def check_readable_file(file, &block)
    if File.exist?(file) && File.readable?(file)
      instance_eval(&block) if block_given?
    end
  end

  def check_writeable_file(file, &block)
    if File.exist?(file) && File.writable?(file)
      instance_eval(&block) if block_given?
    end
  end

  def on_linux(&block)
    if RbConfig::CONFIG['host_os'] =~ /linux/i
      instance_eval(&block) if block_given?
    end
  end

  def on_macos(&block)
    if RbConfig::CONFIG['host_os'] =~ /darwin/i
      instance_eval(&block) if block_given?
    end
  end

  def on_bsd_ls(&block)
    @commands << <<~ZSH
      if ls --version 2>&1 | grep -q "BSD coreutils" || ls --version 2>&1 | grep -q "macOS"; then
        #{instance_eval(&block) if block_given?}
      fi
    ZSH
  end

  def on_gnu_ls(&block)
    @commands << <<~ZSH
      if ls --version 2>&1 | grep -q "GNU coreutils"; then
        #{instance_eval(&block) if block_given?}
      fi
    ZSH
  end

  def on_solaris_ls(&block)
    @commands << <<~ZSH
      if ls --version 2>&1 | grep -q "Solaris"; then
        #{instance_eval(&block) if block_given?}
      fi
    ZSH
  end

  def to_zsh_script
    script = []
    @env_updates.each { |name, value| script << "export #{name}=\"#{value}\"" }
    @alias_updates.each do |name, command|
      next if name.to_s.strip.empty? || command.to_s.strip.empty?
      cmd = command.to_s
      quote_char = cmd.include?("'") ? '"' : "'"
      script << "alias #{name}=#{quote_char}#{cmd}#{quote_char}"
    end

    # Process path updates and generate a single PATH export
    if @path_updates.any?
      new_path_components = ENV['PATH'].split(':')
      paths_to_add = []

      @path_updates.each do |update|
        directory = update[:directory]
        position = update[:position]

        if Dir.exist?(directory) && File.readable?(directory) && !new_path_components.include?(directory)
          if position == :before
            new_path_components.unshift(directory)
          elsif position == :after
            new_path_components.push(directory)
          end
        end
      end

      # Remove duplicates while preserving order of first occurrence
      final_path_components = []
      new_path_components.each { |path| final_path_components << path unless final_path_components.include?(path) }

      script << "export PATH=\"#{final_path_components.join(':')}\""
    end

    script.concat(@commands)
    script.join("\n")
  end

  private

  def executable_exists?(executable)
    ENV['PATH'].split(':').any? { |path| File.executable?(File.join(path, executable)) }
  end

  def same_command?(alias_command, executable)
    alias_command.split.first == executable
  end
end

def configure_shell(&block)
  configurator = ShellConfigurator.new
  configurator.instance_eval(&block)
  puts configurator.to_zsh_script
end
