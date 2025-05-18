# lib_checker.rb: Check and load Ruby gems based on parameters.
# frozen_string_literal: true

module LibChecker
  # Verbose logging turned off by default
  @verbose = false

  class << self
    attr_reader :verbose
  end

  def self.load(gems, options = {})
    @verbose = options.fetch(:verbose, false)
    puts "Checking for required gems..." if @verbose

    # Ensure the argument is always an array
    missing_gems = load_gems Array(gems)

    unless missing_gems.empty?
      warn "\nError: The following required Ruby gems are missing:"
      missing_gems.each do |gem_name|
        warn "  - #{gem_name}"
      end

      warn "\nPlease install them. You can try:"
      warn "  gem install #{missing_gems.join(' ')}"
      warn "Or, if using Bundler, ensure your Gemfile is complete and run 'bundle install'."
      exit 1
    end

    puts "All required gems are present." if @verbose
    true
  end

  def self.load_gems(to_check)
    missing = []
    to_check.each do |gem_name|
      require gem_name
      puts "Successfully loaded '#{gem_name}'." if @verbose
    rescue LoadError
      missing << gem_name
    end

    missing # Return the array of missing gems
  end

end
