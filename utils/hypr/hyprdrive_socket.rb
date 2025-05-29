#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/lib_checker"

LibChecker.load(
  gems: %w[yaml pathname],
  libs: [],
  base: __dir__
)

module HyprdriveSocket
  # Default socket configuration
  DEFAULT_CONFIG = {
    uri: "drbunix:/tmp/hyprdrive.sock",
    timeout: 5,
    retry_attempts: 3,
    retry_delay: 1
  }.freeze

  # Configuration file paths in order of precedence
  CONFIG_PATHS = [
    File.expand_path("~/.config/hyprdrive/socket.yml"),
    File.expand_path("~/.config/hyprdrive/socket.yaml"),
    File.expand_path("socket.yml", __dir__)
  ].freeze

  class Config
    attr_reader :uri, :timeout, :retry_attempts, :retry_delay

    def initialize(config = {})
      @uri = config[:uri] || DEFAULT_CONFIG[:uri]
      @timeout = config[:timeout] || DEFAULT_CONFIG[:timeout]
      @retry_attempts = config[:retry_attempts] || DEFAULT_CONFIG[:retry_attempts]
      @retry_delay = config[:retry_delay] || DEFAULT_CONFIG[:retry_delay]
    end

    def self.load
      config_path = CONFIG_PATHS.find { |path| File.exist?(path) }
      return new unless config_path

      begin
        yaml_data = File.read(config_path)
        config = YAML.safe_load(yaml_data, symbolize_names: true)
        new(config)
      rescue StandardError => e
        warn "Warning: Failed to load socket configuration from #{config_path}: #{e.message}"
        new
      end
    end
  end
end
