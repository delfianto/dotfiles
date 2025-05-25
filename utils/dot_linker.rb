#!/usr/bin/env ruby
# dot.rb: Simple dotfile package linker in Ruby.
# frozen_string_literal: true

require_relative "log_conf"
LibChecker.load(%w[
  fileutils
  pathname
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
    padding = longest.length + MOD_LOGS.length

    mod_names.each do |mod_name|
      @mod_log = "[#{MOD_LOGS}#{mod_name.upcase.ljust(padding)}]"
      mod_dir = File.join(@dotfiles_dir, mod_name)

      unless Dir.exist?(mod_dir)
        mlog(:warn, "Module path does not exist: {path}", { path: mod_dir })
        next
      end

      mlog("Module name: #{mod_name}")
      mlog("Module path: {path}", { path: mod_dir })

      maps = map_module_path(mod_name)
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
    prefixed_message = "#{@mod_log} #{formatted_message}"

    if exception
      LogUtils.log_exception(@log, prefixed_message, exception)
    else
      @log.send(level, prefixed_message)
    end
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
      mlog(:warn, "#{mod_name}: No data found for #{MOD_INFO} key in YAML.")
      return {}.freeze
    end

    result_hash = paths_to_process.each_with_object({}) do |(target_key, items), hash|
      if @relative
        target_key_sym = target_key.split(":").first.to_sym
        base_target_dir = dotfiles_link(BASE_DIR_MAPPINGS[target_key_sym])
      else
        base_target_dir = @dotfiles_dir
      end

      items.each do |item|
        mlog(:debug, "--- ENTRY ---")
        path = map_entry_paths(item)
        link_path = build_link_path(target_key, mod_name, path[:link_path])
        dest_path = build_dest_path(base_target_dir, mod_name, path[:dest_path])

        unless File.exist?(dest_path)
          mlog(:warn, "Target does not exist: {path}", { path: dest_path })
          next
        end

        hash[dest_path.to_s] = link_path.to_s
      end
    end

    result_hash.freeze
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

    config_data.freeze
  rescue Psych::SyntaxError => e
    mlog("Invalid YAML syntax!", exception: e)
    {}.freeze
  rescue StandardError => e
    mlog("Could not load YAML!", exception: e)
    {}.freeze
  end

  # Maps the source and destination paths from the item.
  # :link_path is the symbolic link_path name
  # :dest_path is the actual real object destination
  # command line equivalents: `ln -s :dest_path :link_path`
  def map_entry_paths(item)
    # Remove potential leading special chars like '*' or ':'
    # if they are prefixes for the whole item string and
    # split the result into at most 2 parts
    paths = item.to_s.gsub(/^[:*]+/, "").split(":", 2)

    link_p = paths[0]
    dest_p = paths.size > 1 ? paths[1] : paths[0] # If no colon, dest is same as link

    if link_p.nil? || link_p.empty?
      mlog("Using module dir for link name")
      return { link_path: nil, dest_path: nil }.freeze
    end

    { link_path: link_p, dest_path: dest_p }.freeze
  end

  def build_link_path(target_key, mod_name, path)
    paths = target_key.gsub("$", mod_name).split(":")
    first_path = paths.first

    base_path = BASE_DIR_MAPPINGS.fetch(
      first_path.to_sym,
      File.join(Dir.home, first_path)
    )

    components = [base_path, *paths[1..], path]
    link_path = File.join(*components.compact)

    mlog(:debug, "Base: {path}", { path: base_path })
    mlog(:debug, "Link: {path}", { path: link_path })
    link_path
  end

  def build_dest_path(base_target_dir, mod_name, path)
    components = [base_target_dir, mod_name, path]
    dest_path = File.join(*components.compact)

    mlog(:debug, "Dest: {path}", { path: dest_path })
    dest_path
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
    compute_link_path = lambda {
      if @relative
        dir = Pathname(link_path).dirname
        Pathname(dest_path)
          .relative_path_from(dir)
          .to_s
      else
        link_path
      end
    }

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

  # Class DotLinker
end

if $PROGRAM_NAME == __FILE__
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
