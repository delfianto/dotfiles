#!/usr/bin/env ruby
# frozen_string_literal: true
# lib_checker.rb: Check and load Ruby gems based on parameters.

module LibChecker

  def self.load(gems, options = {})
    # Ensure the argument is always an array
    to_check = Array(gems)
    missing = []
    verbose = options.fetch(:verbose, false)

    puts "Checking for required gems..." if verbose
    to_check.each do |gem_name|
      begin
        require gem_name
        puts "Successfully loaded '#{gem_name}'." if verbose
      rescue LoadError
        missing_gems << gem_name
      end
    end

    unless missing.empty?
      warn "\nError: The following required Ruby gems are missing:"
      missing.each do |gem_name|
        warn "  - #{gem_name}"
      end

      warn "\nPlease install them. You can try:"
      warn "  gem install #{missing.join(' ')}"
      warn "Or, if using Bundler, ensure your Gemfile is complete and run 'bundle install'."
      exit 1
    end

    puts "All required gems are present." if verbose
    true
  end

end
