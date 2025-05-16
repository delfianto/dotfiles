# frozen_string_literal: true
# lib_runner.rb: Common functions to check for ARGV.

require 'slop'

class CLIRunner
  # --- Class-level DSL and Configuration ---
  class << self
    attr_reader :option_definitions_dsl, :custom_help_sections_dsl, :main_action_method_name_dsl

    # Called when a class inherits from InheritableCLIRunner
    def inherited(subclass)
      super
      # Each subclass gets its own set of definitions, inheriting from parent if any
      # For simplicity here, we start fresh, but deep cloning could be used for inheritance of definitions.
      subclass.instance_variable_set(:@option_definitions_dsl, [])
      subclass.instance_variable_set(:@custom_help_sections_dsl, [])
      subclass.instance_variable_set(:@main_action_method_name_dsl, :execute) # Default action method
    end

    # DSL method for subclasses to define an option
    # Example: option :profile, type: :string, short: '-p', desc: 'User profile'
    #          option :verbose, type: :boolean, short: '-v', desc: 'Enable verbosity'
    #          action_option :list, long: '--list-all', desc: 'List all items' do |cli_instance| ... end
    def option(name, type: :boolean, desc: '', **slop_args)
      @option_definitions_dsl << { name: name, type: type, desc: desc, args: slop_args, block: nil }
    end

    # DSL method for options that trigger an immediate action (like --list-profiles)
    def option_exec(name, desc: '', **slop_args, &block)
      raise ArgumentError, "Action block is required for action_option" unless block_given?
      @option_definitions_dsl << { name: name, type: :action, desc: desc, args: slop_args, block: block }
    end

    # DSL method for subclasses to add custom help sections
    # The block will be instance_eval'd in the context of the CLI instance.
    def help_section(title, &block)
      raise ArgumentError, "Content block is required for help_section" unless block_given?
      @custom_help_sections_dsl << { title: title, content_block: block }
    end

    # DSL method for subclasses to specify the main action method name
    def main_action_is(method_name)
      @main_action_method_name_dsl = method_name.to_sym
    end

    # Class method to start the CLI application
    def start(argv = ARGV)
      # Creates an instance of the subclass and runs it
      new.run_cli(argv)
    end
  end # class << self

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

  # Configures the Slop::Options instance based on class-level definitions
  def configure_slop_parser
    # Standard options
    @slop_parser.on '-h', '--help', 'Print this help message' do
      print_help_and_exit(0)
    end
    if @version
      @slop_parser.on '--version', 'Show application version' do
        puts "#{@app_name} version #{@version}"
        exit 0
      end
    end

    # Add options defined by the subclass using the DSL
    self.class.option_definitions_dsl&.each do |opt_def|
      flags = []
      flags << opt_def[:args][:short] if opt_def[:args][:short]
      flags << opt_def[:args][:long] if opt_def[:args][:long]
      # Remove short/long from args as they are passed positionally to Slop
      slop_specific_args = opt_def[:args].reject { |k, _| [:short, :long].include?(k) }

      if opt_def[:type] == :action
        # For action_option, pass the block to slop.on
        # The block will receive the option and value (often nil for simple flags)
        # We capture `self` (the CLI instance) to pass to the user's block.
        cli_instance = self
        @slop_parser.on(*flags, opt_def[:desc], **slop_specific_args) do |_opt, _val|
          # Call the user's block, passing the CLI instance
          opt_def[:block].call(cli_instance)
        end
      else
        # For regular options (string, boolean, etc.)
        slop_method = opt_def[:type].to_sym
        if @slop_parser.respond_to?(slop_method)
          @slop_parser.public_send(slop_method, *flags, opt_def[:desc], **slop_specific_args)
        else
          warn "Warning: Unsupported Slop option type '#{slop_method}' for option ':#{opt_def[:name]}'."
        end
      end
    end
  end

  def print_help_and_exit(exit_code = 0, error_message = nil)
    if error_message
      STDERR.puts "Error: #{error_message}"
      STDERR.puts ""
    end
    puts @slop_parser.to_s # Slop's generated help

    self.class.custom_help_sections_dsl&.each do |section_def|
      puts "\n#{section_def[:title]}:"
      # instance_eval allows the block to access instance methods/variables of the CLI subclass
      content = instance_eval(&section_def[:content_block])
      content.to_s.each_line { |line| puts "  #{line.chomp}" }
    end
    exit exit_code
  end

  # Main execution flow for the CLI instance
  def run_cli(argv)
    begin
      if argv.empty? && self.class.option_definitions_dsl&.any?
        print_help_and_exit(1, "No options provided.")
      end

      slop_result = @slop_parser.parse(argv)
      @parsed_options = slop_result # Slop::Result object
      @remaining_args = slop_result.arguments

      action_method_sym = self.class.main_action_method_name_dsl
      if respond_to?(action_method_sym, false) # Check only public/protected methods of the instance
        public_send(action_method_sym) # Call the designated action method
      else
        # Fallback if no action method is found or defined, print help.
        print_help_and_exit(1, "No action defined for these inputs. Implement '##{action_method_sym}'.")
      end

    rescue Slop::MissingArgument => e
      print_help_and_exit(1, e.message)
    rescue Slop::UnknownOption => e
      print_help_and_exit(2, e.message)
    rescue Slop::Error => e
      print_help_and_exit(3, "Options parsing error: #{e.message}")
    rescue StandardError => e
      STDERR.puts "Application Error (#{e.class.name}): #{e.message}"
      STDERR.puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}" if ENV['DEBUG']
      exit 4
    end
  end

  # Default action method. Subclasses should override this or specify a different one
  # using `main_action_is :your_method_name`.
  # This method can access `parsed_options` and `remaining_args` instance variables.
  def execute
    puts "InheritableCLIRunner: Default 'execute' method called. Parsed options:"
    pp parsed_options.to_hash if parsed_options
    puts "Remaining arguments: #{remaining_args.join(', ')}" unless remaining_args.empty?
    print_help_and_exit(0, "Please implement the '#{self.class.main_action_method_name_dsl}' method in #{self.class.name}.")
  end
end
