# logger_utils.rb: Utility class for logging messages.
# frozen_string_literal: true

module LogUtils
  # Helper function to log an exception with its message and stacktrace.
  #
  # @param exc [Exception] The exception object to log.
  # @param message [String] A custom message to prepend to the log.
  # @param level [Symbol] The log level to use (e.g., :error, :warn).
  # @param logger [Logging::Logger, nil] The logger instance to use.
  #        If nil, defaults to Logging.logger[LoggerUtils].
  def self.log_exception(exc, message: "An exception occurred", level: :error, logger: nil)
    # Use the provided logger or get a default one named after this module
    log = logger || Logging.logger[self] # 'self' here refers to LogUtils

    log.send(level, message)
    log.send(level, "Exception: #{exc.class}")

    exc.message.split(":", 2).each do |part|
      entry = part.gsub(/\A\(|\)\z/, "").strip
      log.send(level, "Exception: #{entry}")
    end

    exc.backtrace&.each { |line| log.send(level, "  #{line}") }
  end

  # Interpolates path placeholders (e.g., {path}) in a message string.
  # Replaces Dir.home with '~' for brevity.
  #
  # @param message [String] The message string with placeholders.
  # @param paths [Hash] A hash where keys are placeholder names (String or Symbol)
  #                     and values are the actual path strings.
  # @return [String] The message string with placeholders interpolated.
  def self.interpolate_paths(message, paths = {})
    return message if paths.nil? || paths.empty?

    formatted_message = message.to_s.dup # Ensure message is a string

    paths.each do |key, path_value|
      path_string = path_value.to_s # Ensure it's a string
      shortened_path = path_string.sub(/\A#{Regexp.escape(Dir.home)}/, "~")
      formatted_message.gsub!(/\{#{key}\}/, shortened_path)
    end

    formatted_message
  end

  # Module LogUtils
end
