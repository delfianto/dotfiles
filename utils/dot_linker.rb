#!/usr/bin/env ruby
# dot.rb: Simple dotfile package linker in Ruby.
# frozen_string_literal: true

require_relative "logger_config"
LibChecker.load(%w[
  fileutils
  time
  yaml
].freeze)

BASE_DIR_MAPPINGS = {
  home: Dir.home,
  cache_home: File.join(Dir.home, ".cache"),
  config_home: File.join(Dir.home, ".config"),
  data_home: File.join(Dir.home, ".local", "share"),
  local_bin: File.join(Dir.home, ".local", "bin"),
  local_dir: File.join(Dir.home, ".local")
}.freeze

class DotLinker
  MOD_LOGS = "MOD:"
  MOD_FILE = "mod.yml"
  MOD_INFO = "mod_info"

  def initialize
    @dotfiles_dir = File.expand_path("..", __dir__)
    @log = Logging.logger[self]
    @dry_run = false
    @mod_log = ""

    if @dry_run
      @log.warn("--- DRY RUN ---")
      @log.warn("--- No actual linking will be performed ---")
    end

    @log.info "Dotfiles path: #{short_log(@dotfiles_dir)}"
  end

  def process_modules(mod_names)
    @log.info "Requested modules: #{mod_names.join(', ')}"
    padding = pad_len(mod_names)

    mod_names.each do |mod_name|
      mod_text = "#{MOD_LOGS}#{mod_name.upcase}"
      @mod_log = "[#{mod_text.ljust(padding)}]"

      mod_dir = File.join(@dotfiles_dir, mod_name)
      mod_dir_log = short_log(mod_dir)

      unless Dir.exist?(mod_dir)
        @log.warn "#{@mod_log} Module path does not exist: #{mod_dir_log}"
        next
      end

      @log.info "#{@mod_log} Module name: #{mod_name}"
      @log.info "#{@mod_log} Module path: #{mod_dir_log}"

      maps = map_module_path(mod_name)
      maps.each do |dest, link|
        symlink(dest, link)
      end
    end
  end

  private # Make methods below this line private

  def pad_len(mod_names)
    longest = mod_names.max_by(&:length)
    raise ArgumentError, "No modules provided" if longest.nil?

    longest.length + MOD_LOGS.length
  end

  # Shortens the path for logging purposes.
  # This method replaces the home directory with a tilde (~).
  # Actual path operations are still using the expanded name.
  def short_log(path)
    return path unless path.start_with?(Dir.home)

    path.sub(Dir.home, "~")
  end

  # Maps the module path from the YAML configuration.
  # This method reads the entries and constructs the full paths.
  # It returns a hash with the destination as the key and the source as the value.
  def map_module_path(mod_name)
    config_data = parse_yaml(mod_name)
    return config_data if config_data.empty?

    # Ensure config_data[MOD_INFO] is not nil before calling reduce
    paths_to_process = config_data[MOD_INFO]
    unless paths_to_process
      @log.warn "#{@mod_log} #{mod_name}: No data found for MOD_INFO key in YAML."
      return {}.freeze
    end

    result_hash = paths_to_process.each_with_object({}) do |(dest_key, items), hash|
      items.each do |item|
        @log.debug "#{@mod_log} --- ENTRY ---"
        path = map_entry_paths(item)
        link = build_link_path(dest_key, mod_name, path[:link])
        dest = build_dest_path(mod_name, path[:dest])

        unless File.exist?(dest)
          @log.warn "#{@mod_log} Target does not exist: #{short_log(dest)}"
          next
        end

        hash[dest.to_s] = link.to_s
      end
    end

    result_hash.freeze
  end

  def build_link_path(dest_key, mod_name, path)
    paths = dest_key.gsub("$", mod_name).split(":")
    first_path = paths.first

    base_path = BASE_DIR_MAPPINGS.fetch(
      first_path.to_sym,
      File.join(Dir.home, first_path)
    )

    components = [base_path, *paths[1..], path]
    link = File.join(*components.compact)\

    @log.debug "#{@mod_log} Base: #{short_log(base_path)}"
    @log.debug "#{@mod_log} Link: #{short_log(link)}"
    link
  end

  def build_dest_path(mod_name, path)
    components = [@dotfiles_dir, mod_name, path]
    dest = File.join(*components.compact)

    @log.debug "#{@mod_log} Dest: #{short_log(dest)}"
    dest
  end

  # Maps the source and destination paths from the item.
  # :link is the symbolic link name
  # :dest is the actual real object destination
  # command line equivalents: `ln -s :dest :link`
  def map_entry_paths(item)
    paths = item.to_s.gsub("*", "").split(":")
    return { link: nil, dest: nil } if paths.empty?

    # Raise an error if the item format is invalid
    # This assumes the item should have at least one segment
    # and at most two segments.
    #
    # For example:
    # - "source:target" is valid
    # - ":source" is valid
    # - "source:" is valid
    # - "source" is valid
    # - "source:target:extra" is invalid
    raise ArgumentError, "Invalid item format: #{item}" unless paths.size < 3

    if paths.size == 1
      {
        link: paths[0],
        dest: paths[0]
      }
    else
      {
        link: paths[0],
        dest: paths[1]
      }
    end
  end

  # Parse the mod.yml file to get the source and destination paths.
  def parse_yaml(mod_name)
    mod_conf = File.join(@dotfiles_dir, mod_name, MOD_FILE)

    @log.info "#{@mod_log} Module conf: #{short_log(mod_conf)}"
    @log.info "#{@mod_log} Parsing module file..."
    config_data = YAML.load_file(mod_conf)

    unless config_data && config_data[MOD_INFO].is_a?(Hash)
      @log.fatal "#{@mod_log} Invalid config structure, no '#{MOD_INFO}' section found!"
      return {}
    end

    config_data
  rescue Psych::SyntaxError => e
    LoggerConfig.log_exception(@log, "#{@mod_log} Invalid YAML syntax!", e)
    {}
  rescue StandardError => e
    LoggerConfig.log_exception(@log, "#{@mod_log} Could not load YAML!", e)
    {}
  end

  def symlink(dest, link)
    ops_flag = check_ops_flag(dest, link)

    if ops_flag[:backup]
      backup(dest, link)
    elsif !ops_flag[:force]
      @log.info "#{@mod_log} Removing link at #{short_log(link)}"
      FileUtils.rm(link, noop: @dry_run)
    end

    # In FileUtils link method, the first argument (src) is the link name
    # and the second (dest) is the target. This is the opposite of the ln command.
    @log.info "#{@mod_log} Creating link { #{short_log(dest)} -> #{short_log(link)} }"
    FileUtils.ln_s(dest, link, force: ops_flag[:force], noop: @dry_run)
  rescue Errno::ENOENT => e
    LoggerConfig.log_exception(@log, "#{@mod_log} Error on file operations!", e)
    false
  rescue StandardError => e
    LoggerConfig.log_exception(@log, "#{@mod_log} Unexpected error!", e)
    false
  end

  # Define operation flags based on the type of destination and link path
  def check_ops_flag(dest, link)
    # When the force flag is false it means that we must remove the symlink manually
    # as FileUtils does not have the capability to override existing symlink (ln -sfn).
    # This is the case when the existing symlink points to a directory
    ops = { force: false, backup: false }

    if File.symlink?(link)
      if File.directory?(dest)
        @log.info "#{@mod_log} Existing link found with a directory as target"
      elsif File.file?(dest)
        @log.info "#{@mod_log} Existing link found with a file as target, using force flag"
        ops[:force] = true
      elsif !File.exist?(link)
        @log.info "#{@mod_log} Found an existing broken link: #{link}"
        ops[:force] = true
      end
    else
      ops[:backup] = true
    end

    ops
  end

  def backup(dest, link)
    bak_root = File.join(File.dirname(link), "_dot_backup")
    FileUtils.mkdir_p(bak_root, noop: @dry_run)

    bak_name = "#{File.basename(dest)}_backup_#{Time.now.strftime('%F_%T')}"
    bak_path = File.join(bak_root, bak_name)

    @log.info "#{@mod_log} Creating backup: #{short_log(bak_path)}"
    FileUtils.move(link, bak_path, noop: @dry_run)
  end

  # Class DotLinker
end

linker = DotLinker.new
linker.process_modules(ARGV)
