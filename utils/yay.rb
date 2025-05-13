#!/usr/bin/env ruby
# frozen_string_literal: true
# yay.rb ~ Ruby wrapper for yay (Yet Another Yaourt) AUR helper

require 'open3'

# Helper function to check if a command exists
def command_exists?(command)
  system("command -v #{command} > /dev/null 2>&1")
end

# Helper function to run a command and capture its output
def capture_command_output(cmd)
  stdout, stderr, status = Open3.capture3(cmd)
  status.success? ? stdout.strip : nil
end

# Main function to handle package commands
def pkg_cmd(args)
  unless command_exists?('yay')
    warn "Error: 'yay' command not found."
    return 1
  end

  command = args.shift
  remaining_args = args.join(' ')

  case command
  when 'logs'
    system('cat /var/log/pacman.log')
  when 'build'
    system('makepkg -sc')
  when 'check'
    system("yay #{remaining_args}")
  when 'clean'
    system("echo 'y' | yay -Sc")
  when 'deps'
    system("pactree -d 1 #{remaining_args}")
  when 'file'
    system("yay -Qlq #{remaining_args}")
  when 'find'
    system("yay -Ss #{remaining_args}")
  when 'info'
    system("yay -Qi #{remaining_args}")
  when 'stat'
    system('yay -Ps')
  when 'orphan'
    system('yay -Qdtq')
  when 'nodeps'
    orphan_pkgs = capture_command_output('yay -Qdtq')
    if orphan_pkgs && !orphan_pkgs.empty?
      # ANSI escape codes for red color
      puts "\e[31mWARNING: Removing all unneeded dependencies...\e[0m"
      system('yay -Yc')
    else
      puts 'No unneeded dependencies in the system.'
    end
  when 'l', 'ls', 'list'
    system("yay -Qs #{remaining_args}")
  when 'i', 'in', 'install'
    system("yay -Sy #{remaining_args}")
  when 'r', 'rm', 'remove'
    system("yay -R #{remaining_args}")
  when 'u', 'up', 'upgrade'
    system('yay -Syu')
  when 's', 'sy', 'update'
    system('yay -Syy')
  when 'q', 'qu', 'quiet'
    system('yay --editmenu --nocleanmenu --nodiffmenu --noeditmenu --noremovemake --save')
  else
    # If no specific command is matched, pass all original arguments to yay
    all_args = ([command] + args).compact.join(' ') # Reconstruct args if command was not nil
    system("yay #{all_args}")
  end
end

# Entry point for the script
if $PROGRAM_NAME == __FILE__
  if ARGV.empty?
    puts 'Usage: pkg_cmd <command> [args...]'
    puts 'Example: pkg_cmd install neovim'
    puts 'Available commands: logs, build, check, clean, deps, file, find, info, stat, orphan, nodeps, list, install, remove, upgrade, update, quiet'
    exit 1
  end
  exit_status = pkg_cmd(ARGV.dup) # Pass a duplicate of ARGV as it can be modified
  exit exit_status if exit_status.is_a?(Integer)
end
