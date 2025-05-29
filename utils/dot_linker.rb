#!/usr/bin/env ruby
# dot_linker.rb: Simple dotfile package linker in Ruby.
# frozen_string_literal: true

require_relative "lib/lib_checker"

LibChecker.load(
  gems: %w[fileutils logging pathname time yaml],
  libs: %w[lib/logger_config lib/log_utils],
  base: __dir__
)

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
  REPO_SYMLINK_NAME = "dotfiles"

  def initialize
    @dotfiles_dir = File.expand_path("..", __dir__)
    @log = Logging.logger[self]
    @mod_log = ""

    @relative = true
    @dry_run = true
    @verbose = true

    if @dry_run
      @log.warn("--- DRY RUN ---")
      @log.warn("--- No actual linking will be performed ---")
    end

    mlog("Dotfiles path: {path}", { path: @dotfiles_dir })
  end

  def process_modules(mod_names)
    longest = mod_names.max_by(&:length)
    raise ArgumentError, "No modules provided" if longest.nil?

    mlog("Requested modules: #{mod_names.join(', ')}")
    mod_names.each do |mod_name|
      @mod_log = "[#{MOD_LOGS}#{mod_name.upcase.ljust(longest.length)}]"
      mod_dir = File.join(@dotfiles_dir, mod_name)

      unless Dir.exist?(mod_dir)
        mlog(:warn, "Module path does not exist: {path}", { path: mod_dir })
        next
      end

      mlog("Module name: #{mod_name}")
      mlog("Module path: {path}", { path: mod_dir })

      mod_entries = parse_yaml(mod_name)
      maps = map_entry(mod_name, mod_entries)

      maps.each do |dest_path, link_path|
        mlog("--- PROCESS ---")
        symlink(dest_path, link_path)
      end
    end

    # Reset module log prefix after processing
    @mod_log = ""
  end

  private # Make methods below this line private

  # Helper for module-specific logging. Automatically prepends @mod_log and formats
  # paths using short_log logic directly. Use placeholders like {path}, {link}, {target}, etc.
  # in the message string, and provide a hash of path keys to values.
  # Accepts an optional `exception:` keyword argument to log exceptions.
  #
  # Defaults to :info level if the first argument is not a symbol specifying the level,
  # unless an exception is present, which forces the level to :error.
  def mlog(*args, exception: nil)
    level = :info # Start with default info

    if args.first.is_a?(Symbol)
      # Take the symbol as the level if provided
      level = args.shift
    end

    message = args.shift     # The next argument is the message
    paths = args.shift || {} # The last argument is the paths hash, or default {}

    # Proceed with formatting and logging using level, message, and paths
    formatted_message = LogUtils.interpolate_paths(message, paths)
    prefixed_message = @mod_log.empty? ? formatted_message : "#{@mod_log} #{formatted_message}"

    if exception
      LogUtils.log_exception(exception, logger: @log)
    else
      @log.send(level, prefixed_message)
    end
  end

  # Parse the mod.yml file to get the source and destination paths.
  def parse_yaml(mod_name)
    mod_conf = File.join(@dotfiles_dir, mod_name, MOD_FILE)

    mlog("Module path: {path}", { path: mod_conf })
    mlog("Parsing module file...")
    config_data = YAML.load_file(mod_conf)

    unless config_data && config_data[MOD_INFO].is_a?(Hash)
      mlog(:fatal, "Invalid config structure, no '#{MOD_INFO}' section found!")
      return {}.freeze
    end

    path_hash = config_data[MOD_INFO]
    unless path_hash.is_a?(Hash)
      mlog(:warn, "#{mod_name}: No data or invalid format for '#{MOD_INFO}' key in YAML. Expected a Hash.")
      return {}.freeze
    end

    path_hash.freeze
  rescue Psych::SyntaxError => e
    mlog("Invalid YAML syntax!", exception: e)
    {}.freeze
  rescue StandardError => e
    mlog("Could not load YAML!", exception: e)
    {}.freeze
  end

  def map_entry(mod_name, yaml_entries)
    dest_dir = File.join(@dotfiles_dir, mod_name)

    result_hash = yaml_entries.each_with_object({}) do |(dest_key, items), outer_hash|
      dest_key_sym = dest_key.to_sym
      link_dir = BASE_DIR_MAPPINGS[dest_key_sym]

      unless link_dir
        mlog(:warn, "Base directory mapping not found for key: #{dest_key}")
        # Skip this group if its base directory isn't defined
        next
      end

      unless items.is_a?(Array)
        mlog(:warn, "Expected an array of items for '#{dest_key}'")
        mlog(:warn, "Got #{items.class}. Skipping...")
        next
      end

      outer_hash[link_dir.to_sym] =
        map_sub_entry(link_dir, dest_dir, mod_name, items)
    end

    result_hash.freeze
  end

  def map_sub_entry(link_dir, dest_dir, mod_name, items)
    entry_hash = lambda do |item|
      parts = item.to_s.gsub(/[*]+/, "")
                  .gsub(/^\$/, mod_name)
                  .split(":", 2)

      link_info = parts[0]
      link_path = File.join(link_dir, link_info)

      # If no colon, dest is same as link
      dest_info = parts.size > 1 ? parts[1] : parts[0]
      dest_path = dest_info.empty? ? dest_dir : File.join(dest_dir, dest_info)

      { link: link_path, dest: dest_path }.freeze
    end

    sub_entries = items.each_with_object([]) do |(item), list|
      list << entry_hash.call(item)
    end

    sub_entries.freeze
  end

  # Ensures the base symlink (e.g., ~/.config/dotfiles -> ~/.dotfiles)
  # already exists if relative linking is active.
  def dotfiles_link(base_target_dir)
    # For home directory ignore this logic as this is considered to be
    # the topmost level of all possible files
    return @dotfiles_dir if base_target_dir == Dir.home

    # example:
    # base_target_dir = ~/.config,
    # @dotfiles_dir = ~/.dotfiles
    # REPO_SYMLINK_NAME = "dotfiles"
    # repo_symlink_full_path becomes ~/.config/dotfiles
    dotfiles_link = File.join(base_target_dir, REPO_SYMLINK_NAME)
    mlog("Checking dotfiles link { {link} -> {target} }",
         { link: dotfiles_link, target: @dotfiles_dir })

    if File.symlink?(dotfiles_link)
      if File.readlink(dotfiles_link) == @dotfiles_dir
        mlog("Dotfiles link found...")
        return dotfiles_link
      end

      mlog(:warn, "Found dotfiles link to {path}", path: dotfiles_link)
      FileUtils.rm(dotfiles_link, noop: @dry_run, verbose: @verbose)
    elsif File.exist?(dotfiles_link)
      mlog(:error, "{path} exists and is not a symlink!", { path: dotfiles_link })
      mlog(:error, "Please remove it manually or resolve this conflict")

      raise "Conflict with with dotfiles link path #{dotfiles_link}"
    end

    parent_dir = File.dirname(dotfiles_link)
    FileUtils.mkdir_p(parent_dir, noop: @dry_run, verbose: @verbose) unless Dir.exist?(parent_dir)
    FileUtils.ln_s(@dotfiles_dir, dotfiles_link, noop: @dry_run, verbose: @verbose)

    dotfiles_link
  rescue SystemCallError => e
    mlog("Error managing dotfiles link { {link} -> {target} }!",
         { link: dotfiles_link, target: @dotfiles_dir, exception: e })
    raise
  end

  def symlink(dest_path, link_path)
    ops_flag = check_ops_flag(dest_path, link_path)
    return false if ops_flag[:skip]

    if ops_flag[:backup]
      backup(dest_path, link_path)
    elsif ops_flag[:remove_first]
      mlog("Removing existing link: {path}", { path: link_path })
      FileUtils.rm(link_path, noop: @dry_run, verbose: @verbose)
    end

    # As of Ruby 3.4.4 FileUtils.ln_s(relative: true) is bugged
    # https://github.com/ruby/fileutils/issues/129
    compute_link_path = lambda do
      if @relative
        dir = Pathname(link_path).dirname
        Pathname(dest_path)
          .relative_path_from(dir)
          .to_s
      else
        link_path
      end
    end

    link_path_arg = compute_link_path.call
    mlog("Creating link { {dest} -> {link} }", { dest: dest_path, link: link_path_arg })
    FileUtils.ln_s(dest_path, link_path_arg, force: ops_flag[:force], noop: @dry_run, verbose: @verbose)
  rescue Errno::ENOENT => e
    mlog("Error on file operations!", exception: e)
    false
  rescue StandardError => e
    mlog("Unexpected error!", exception: e)
    false
  end

  # Define operation flags based on the type of destination and link_path path
  def check_ops_flag(dest_path, link_path)
    # When the remove_first flag is true it means that we must remove the symlink manually
    # as FileUtils does not have the capability to override existing symlink (ln -sfn).
    # This is the case when the existing symlink points to a directory
    ops = { backup: false, force: false, remove_first: false, skip: false }

    if !File.exist?(link_path) && !File.symlink?(link_path)
      # Case 1: Link path does not exist at all
      # All ops remain false, just proceed to link.
      mlog("No existing item at {path}", { path: link_path })
    elsif File.symlink?(link_path)
      # Case 2: Link path is an existing symlink
      check_symlink(dest_path, link_path, ops)
    elsif File.exist?(link_path)
      # Case 3: Link path is an existing file or directory (but not a symlink)
      mlog("Existing file/directory found at {path}", { path: link_path })
      ops[:backup] = true
    end

    ops.freeze
  end

  def check_symlink(dest_path, link_path, ops)
    link_path_actual = File.readlink(link_path)

    if !File.exist?(link_path)
      # Case 2a: Broken symlink
      mlog("Found broken link: {path}", path: link_path)
      ops[:force] = true # Force will overwrite the broken symlink
    elsif File.directory?(link_path_actual) && File.directory?(dest_path)
      if link_path_actual == dest_path
        # Case 2b: Existing symlink already points to the correct dest_path.
        # Flag as skip and continue processing other entries.
        mlog("Target is already correct, skipping this entry")
        ops[:skip] = true
      else
        # Case 2c: Existing symlink points to a directory, and new target is also a directory.
        # This aims for \'ln -sfn\' behavior: remove old symlink, then create new one.
        mlog("Target is a directory, preparing to re-link")
        ops[:remove_first] = true
      end
    else
      # Case 2d: Symlink exists, is not broken, and not the dir-to-dir case above.
      # This includes symlink-to-file, symlink-to-non_dir_target etc.
      mlog("Found existing link: {path}", { path: link_path })
      mlog("Link will be overwritten by force!")
      ops[:force] = true
    end
  end

  def backup(dest_path, link_path)
    bak_root = File.join(File.dirname(link_path), "_dot_backup")
    FileUtils.mkdir_p(bak_root, noop: @dry_run, verbose: @verbose)

    bak_name = "#{File.basename(dest_path)}_backup_#{Time.now.strftime('%F_%T')}"
    bak_path = File.join(bak_root, bak_name)

    mlog("Creating backup: {path}", { path: bak_path })
    FileUtils.move(link_path, bak_path, noop: @dry_run, verbose: @verbose)
  end
  # class end
end

if File.expand_path($PROGRAM_NAME) == File.expand_path(__FILE__)
  if ARGV.empty?
    puts "No modules specified on the command line!"
    puts "Usage   : #{$PROGRAM_NAME} [module1 module2 ...]"
    puts "Example : #{$PROGRAM_NAME} hyprland terminal zsh"
    exit 1
  else
    linker = DotLinker.new
    linker.process_modules(ARGV)
  end
end
