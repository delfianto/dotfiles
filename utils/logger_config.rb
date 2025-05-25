# logger_config.rb: Ruby logging gem configurations.
# frozen_string_literal: true

require_relative "lib_checker"
require_relative "log_utils"
LibChecker.load(%w[
  logging
].freeze)

# This module encapsulates all the setup logic for the 'logging' gem.
module LoggerConfig
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

    # 2. Define the layout pattern.
    # [%d]  - Timestamp with 3 decimal places for milliseconds.
    # [%c]  - Logger name (e.g., class name).
    # [%p]  - Process ID.
    # [%M]  - Method name (Note: its reliability can vary; explicit logging of method is often safer).
    # [%5l] - Log level, padded to 5 characters (e.g., "INFO ", "DEBUG").
    # [%m]  - The log message itself.
    layout = Logging.layouts.pattern(
      pattern: "[%d][%c:%p:%t][%5l] %m\n",
      color_scheme: "my_color_scheme", # Use the color scheme defined above
      date_pattern: "%Y-%m-%d %H:%M:%S.%L"
    )

    # Configure the log appender (e.g., writing to STDOUT).
    stdout_appender = Logging.appenders.stdout(
      "my_stdout_appender",
      layout: layout # Use the layout defined above
    )

    # log.add_appenders(stdout_appender)
    # log.level = :debug

    # Configure the root logger.
    # All loggers created via Logging.logger[...] will inherit from the root logger
    # unless specifically configured otherwise.
    Logging.logger.root.appenders = [stdout_appender] # Assign the appender(s)
    Logging.logger.root.level = :debug # Set a global default log level (e.g., :info, :debug)

    # You could add more appenders here, e.g., a file appender:
    # Logging.appenders.file(
    #   "file_configured,
    #   filename: "application.log,
    #   layout: pattern_layout,
    #   level: :info
    # )
    # Logging.logger.root.add_appenders(Logging.appenders['file_configured'])
  end

  # Module LoggerConfig
end

# This line ensures that simply requiring this file will set up the logging.
LoggerConfig.setup!
