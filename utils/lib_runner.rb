# lib_runner.rb: Superclass for CLI applications
# This class provides a framework for building command-line interfaces (CLI) using the Slop gem.
# It allows subclasses to define options, actions, and custom help sections using a simple DSL.
# frozen_string_literal: true

# Load required libraries
require_relative "lib_checker"
LibChecker.load(%w[
  open3
  slop
  shellwords
].freeze)

class CLIRunner
  # --- Class-level DSL and Configuration ---
  class << self
    attr_reader :option_definitions_dsl,
                :custom_help_sections_dsl,
                :main_action_method_name_dsl

    # Called when a class inherits from CLIRunner
    def inherited(subclass)
      super
      # Each subclass gets its own set of definitions, inheriting from parent if any
      # For simplicity here, we start fresh, but deep cloning could be used for inheritance of definitions.
      subclass.instance_variable_set(:@option_definitions_dsl, [])
      subclass.instance_variable_set(:@custom_help_sections_dsl, [])
      subclass.instance_variable_set(:@main_action_method_name_dsl, :execute) # Default action method
    end

    # DSL method for subclasses to define an option
    # Example: option :profile, type: :string, short: "-p", desc: "User profile"
    #          option :verbose, type: :boolean, short: "-v", desc: "Enable verbosity"
    #          action_option :list, long: "--list-all", desc: "List all items" do |cli_instance| ... end
    def option(name, type: :boolean, desc: "", **slop_args)
      @option_definitions_dsl << {
        name: name,
        type: type,
        desc: desc,
        args: slop_args,
        block: nil
      }
    end

    # DSL method for options that trigger an immediate action (like --list-profiles)
    def option_exec(name, desc: "", **slop_args, &block)
      raise ArgumentError, "Action block is required for action_option" unless block_given?

      @option_definitions_dsl << {
        name: name,
        type: :action,
        desc: desc,
        args: slop_args,
        block: block
      }
    end

    # DSL method for subclasses to add custom help sections
    # The block will be instance_eval'd in the context of the CLI instance.
    def help_section(title, &block)
      raise ArgumentError, "Content block is required for help_section" unless block_given?

      @custom_help_sections_dsl << {
        title: title,
        content_block: block
      }
    end

    # DSL method for subclasses to specify the main action method name
    def main_action(method_name)
      @main_action_method_name_dsl = method_name.to_sym
    end

    # Class method to start the CLI application
    def start(argv = ARGV)
      # Creates an instance of the subclass and runs it
      new.process_arguments(argv)
    end
  end

  # --- Instance Methods ---
  attr_reader :slop_parser, :parsed_options, :remaining_args, :app_name, :version

  def initialize(app_name: File.basename($PROGRAM_NAME, ".*"), version: nil)
    @app_name = app_name
    @version = version
    @slop_parser = Slop::Options.new
    @parsed_options = nil
    @remaining_args = []
    configure_slop_parser
  end

  # Public entry point for an instance, called by CLIRunner.start
  # Subclasses *could* override this, but it"s simple and delegates.
  # If a subclass overrides this and doesn"t call super or the private method,
  # they bypass the core logic. This is a limitation without "final" methods.
  def process_arguments(argv)
    run_cli(argv)
  end

  protected # All methods defined after this are protected

  # Accessor methods for slop internal values
  def option_present?(key_symbol)
    return false unless @parsed_options && key_symbol.is_a?(Symbol)

    # Construct the dynamic query method name, e.g., :profile becomes :profile?
    dynamic_query_method = "#{key_symbol}?".to_sym

    # Check if Slop::Result responds to this dynamic method (e.g., .profile?)
    if @parsed_options.respond_to?(dynamic_query_method)
      # Call the dynamic method (e.g., @parsed_options.profile?)
      # This should return true or false
      !!@parsed_options.public_send(dynamic_query_method) # Use !! to ensure true/false
    else
      # Fallback if the dynamic "key?" method isn"t available for some reason
      # (though your debug shows it is for :profile?)
      # You could log a warning here if you expect it to always be available.
      # puts "Warning: Slop::Result does not respond to #{dynamic_query_method}"
      @parsed_options.to_hash.key?(key_symbol) # Check presence in the hash as a last resort
    end
  end

  def option_value(key_symbol)
    return nil unless @parsed_options && key_symbol.is_a?(Symbol)

    # Try the dynamic accessor method first (e.g., @parsed_options.profile)
    if @parsed_options.respond_to?(key_symbol)
      @parsed_options.public_send(key_symbol)
    else
      # Fallback to accessing the value from the hash
      # This is useful if a dynamic accessor isn"t created but the option was parsed
      # Ensure the key exists to differentiate between a missing option and an option with a nil value
      @parsed_options.to_hash[key_symbol] if @parsed_options.to_hash.key?(key_symbol)
    end
  end

  def all_parsed_options
    @parsed_options&.to_hash
  end

  def arguments
    @remaining_args || []
  end

  # Default action method. Subclasses should override this or
  # specify a different one using `main_action :your_method_name`.
  # This method can access `parsed_options` and `remaining_args` instance variables.
  def execute
    puts "CLIRunner: Default 'execute' method called. Parsed options:"
    pp parsed_options.to_hash if parsed_options
    puts "Remaining arguments: #{remaining_args.join(', ')}" unless remaining_args.empty?
    print_help_and_exit(0, "Please implement the '#{self.class.main_action_method_name_dsl}'
                            method in #{self.class.name}.")
  end

  private # All methods defined after this are private

  # Adds standard options like --help and --version
  def standard_slop_options
    @slop_parser.on "-h", "--help", "Print this help message" do
      print_help_and_exit(0)
    end

    return unless @version

    @slop_parser.on "--version", "Show application version" do
      puts "#{@app_name} version #{@version}"
      exit 0
    end
  end

  # Extracts command-line flags (e.g., -f, --flag) from an option definition
  def extract_custom_slop_flags(opt_def)
    flags = []
    flags << opt_def[:args][:short] if opt_def[:args][:short]
    flags << opt_def[:args][:long] if opt_def[:args][:long]
    flags # Returns an array of flag strings
  end

  # Configures a Slop option that triggers an immediate action block
  def add_action_slop_option(opt_def, flags, slop_specific_args)
    cli_instance = self # Capture self for the block context
    @slop_parser.on(*flags, opt_def[:desc], **slop_specific_args) do |_opt, _val|
      opt_def[:block].call(cli_instance) # Execute the user-defined block
    end
  end

  # Configures a regular Slop option (e.g., string, boolean)
  def add_regular_slop_option(opt_def, flags, slop_specific_args)
    slop_method = opt_def[:type].to_sym
    if @slop_parser.respond_to?(slop_method)
      @slop_parser.public_send(slop_method, *flags, opt_def[:desc], **slop_specific_args)
    else
      warn "Warning: Unsupported Slop option type '#{slop_method}' for option ':#{opt_def[:name]}'."
    end
  end

  # Configures the Slop::Options instance based on class-level definitions
  def configure_slop_parser
    # Standard options
    standard_slop_options

    # Custom options defined in the subclass
    self.class.option_definitions_dsl&.each do |opt_def|
      flags = extract_custom_slop_flags(opt_def)
      # Remove short/long from args as they are passed positionally to Slop
      slop_specific_args = opt_def[:args].reject { |k, _| %i[short long].include?(k) }

      if opt_def[:type] == :action
        add_action_slop_option(opt_def, flags, slop_specific_args)
      else
        add_regular_slop_option(opt_def, flags, slop_specific_args)
      end
    end
  end

  def print_help_and_exit(exit_code = 0, error_message = nil)
    output_stream = exit_code.zero? ? $stdout : $stderr

    if error_message
      output_stream.puts "Error: #{error_message}"
      output_stream.puts ""
    end

    # Slop"s generated help
    output_stream.puts @slop_parser.to_s
    self.class.custom_help_sections_dsl&.each do |section_def|
      output_stream.puts "\n#{section_def[:title]}:"
      # instance_eval allows the block to access instance methods/variables of the CLI subclass
      content = instance_eval(&section_def[:content_block])
      content.to_s.each_line { |line| output_stream.puts "  #{line.chomp}" }
    end

    exit exit_code
  end

  def run_cli(argv)
    run_cli_delegate(argv)
  # Fallback for Slop errors
  rescue Slop::MissingArgument => e
    print_help_and_exit(1, e.message)
  rescue Slop::UnknownOption => e
    print_help_and_exit(2, e.message)
  rescue Slop::Error => e
    print_help_and_exit(3, "Options parsing error: #{e.message}")
  rescue StandardError => e
    warn "Application Error (#{e.class.name}): #{e.message}"
    warn "Backtrace:\n\t#{e.backtrace.join("\n\t")}" if ENV["DEBUG"]
    exit 4
  end

  # Main execution flow for the CLI instance
  def run_cli_delegate(argv)
    argv.empty? &&
      self.class.option_definitions_dsl&.any? &&
      print_help_and_exit(1, "No options provided.")

    slop_result = @slop_parser.parse(argv)
    @parsed_options = slop_result # Slop::Result object
    @remaining_args = slop_result.arguments

    # Check for method of the instance and invoke it
    action_method_sym = self.class.main_action_method_name_dsl
    if respond_to?(action_method_sym, false)
      send(action_method_sym)
    else
      # Fallback if no action method is found or defined, print help.
      print_help_and_exit(1, "No action defined for these inputs. Implement '##{action_method_sym}'.")
    end
  end
  # class CLIRunner
end
