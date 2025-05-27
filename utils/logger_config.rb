# logger_config.rb: Ruby logging gem configurations.
# frozen_string_literal: true

require_relative "lib_checker"
require_relative "log_utils"
LibChecker.load(%w[
  logging
].freeze)

# This module encapsulates all the setup logic for the 'logging' gem,
# including optional redirection of STDOUT and STDERR to the logger.
module LoggerConfig
  # IO-like class that sends writes to a Logging logger at a specific level
  class LoggerIO
    @original_stdout = $stdout

    class << self
      attr_reader :original_stdout
    end

    def initialize(logger, level = :info)
      @logger = logger
      @level = level
    end

    def write(msg)
      msg.to_s.each_line do |line|
        @logger.send(@level, line.chomp)
      end
    end

    def puts(msg = "")
      write("#{msg}\n")
    end

    def tty?
      LoggerConfig.original_stdout.tty?
    rescue NoMethodError
      # In case original_stdout doesn't have tty?
      # (e.g. if it was already nil or some other IO object)
      false
    end
    alias isatty tty?

    # Needed for IO compatibility
    def flush; end
  end

  def self.setup!
    # Define color scheme for the logger
    Logging.color_scheme(
      "my_color_scheme",
      levels: {
        info: :blue,
        warn: :yellow,
        error: :red,
        fatal: %i[white on_red], # White text on a red background
        debug: :magenta
      },
      date: :grey,    # Color for the timestamp
      logger: :cyan,  # Color for the logger name (class/module)
      message: :white # Default color for the log message content
    )

    # Define the layout pattern
    # https://www.rubydoc.info/gems/logging/Logging/Layouts/Pattern
    layout = Logging.layouts.pattern(
      pattern: "[%d][%10c:%p:%t][%5l] %m\n",
      color_scheme: "my_color_scheme",
      date_pattern: "%H:%M:%S.%L"
    )

    # Configure the stdout appender
    stdout_appender = Logging.appenders.stdout(
      "my_stdout_appender",
      layout: layout
    )

    # Assign appender and level to root logger
    Logging.logger.root.appenders = [stdout_appender]
    Logging.logger.root.level = :debug

    # Redirect STDOUT and STDERR to the logger
    redirect_std
  end

  # Redirect STDOUT and STDERR to Logging gem loggers
  def self.redirect_std
    # Create named loggers for STDOUT and STDERR
    stdout_logger = Logging.logger["STDOUT"]
    stderr_logger = Logging.logger["STDERR"]

    # Replace global STDOUT and STDERR with LoggerIO objects
    $stdout = LoggerIO.new(stdout_logger, :debug)
    $stderr = LoggerIO.new(stderr_logger, :error)
  end

  private_class_method :redirect_std
end

# Setup logging (including redirect of STDOUT/STDERR) on require
LoggerConfig.setup!
