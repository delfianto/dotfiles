# frozen_string_literal: true

module LibChecker
  @verbose = false

  class << self
    attr_accessor :verbose

    def load(gems: [], libs: [], base: __dir__)
      self.verbose = true if ENV["LIBCHECKER_VERBOSE"]
      puts "[lib_checker] Verifying gem and file dependencies..." if verbose

      missing = []
      missing += load_gems(gems)
      missing += load_files(libs, base)

      unless missing.empty?
        warn "\n[lib_checker] Missing required libraries:"
        missing.each { |m| warn "  - #{m}" }
        warn "\n[lib_checker] Hint: Run `bundle install` or `gem install <name>` as appropriate."
        exit 1
      end

      puts "[lib_checker] All libraries loaded successfully." if verbose
      true
    end

    private

    def load_gems(gems)
      gems.each_with_object([]) do |name, missing|
        require name
        puts "[lib_checker] Gem loaded: #{name}" if verbose
      rescue LoadError
        missing << name
      end
    end

    def load_files(files, base)
      files.each_with_object([]) do |file, missing|
        path = File.expand_path(file, base)
        require path
        puts "[lib_checker] File loaded: #{file}" if verbose
      rescue LoadError => _e
        missing << file
      end
    end
    # class method end
  end
end
