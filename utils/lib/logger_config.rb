# logger_config.rb: Ruby logging gem configurations.
# frozen_string_literal: true

require_relative "log_utils"

# This module encapsulates all the setup logic for the 'logging' gem,
# including optional redirection of STDOUT and STDERR to the logger.
module LoggerConfig
  # IO-like class that sends writes to a Logging logger at a specific level
  class LoggerIO
    @level = :info
    @original_stdout = $stdout

    class << self
      attr_reader :logger, :level, :original_stdout
    end

    def initialize(logger, level = :info, original_stdout = $stdout)
      @logger = logger
      @level = level
      @original_stdout = original_stdout
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
      @original_stdout&.tty? || false
    rescue NoMethodError
      # In case original_stdout doesn't have tty?
      # (e.g. if it was already nil or some other IO object)
      false
    end
    alias isatty tty?

    # Needed for IO compatibility
    def flush; end
    # class end
  end

  def self.setup!(config = {})
    # Default configuration
    default_config = {
      pattern: "[%d][%10c:%p:%t][%5l] %m\n",
      date_pattern: "%H:%M:%S.%L",
      color_scheme: {
        info: :blue,
        warn: :yellow,
        error: :red,
        fatal: %i[white on_red],
        debug: :magenta
      },
      redirect_std: false,
      stdout_logger: Logging.logger["STDOUT"], # Default STDOUT logger
      stderr_logger: Logging.logger["STDERR"]  # Default STDERR logger
    }

    # Merge provided config with defaults
    config = default_config.merge(config)

    # Define color scheme for the logger
    Logging.color_scheme(
      "my_color_scheme",
      levels: config[:color_scheme],
      date: :grey,    # Color for the timestamp
      logger: :cyan,  # Color for the logger name (class/module)
      message: :white # Default color for the log message content
    )

    # Define the layout pattern
    # https://www.rubydoc.info/gems/logging/Logging/Layouts/Pattern
    layout = Logging.layouts.pattern(
      pattern: config[:pattern],
      date_pattern: config[:date_pattern],
      color_scheme: "my_color_scheme"
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
    redirect_std(config[:stdout_logger], config[:stderr_logger]) if config[:redirect_std]
  end

  # Redirect STDOUT and STDERR to Logging gem loggers
  def self.redirect_std(stdout_logger, stderr_logger)
    $stdout = LoggerIO.new(stdout_logger, :debug, $stdout)
    $stderr = LoggerIO.new(stderr_logger, :error, $stderr)
  end

  private_class_method :redirect_std
  # module end
end

# Setup logging (including redirect of STDOUT/STDERR) on require
LoggerConfig.setup!
