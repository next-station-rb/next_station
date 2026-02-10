# frozen_string_literal: true

module NextStation
  # The core class for defining operations.
  #
  # Operations are composed of steps and branches, and they return a NextStation::Result.
  class Operation
    # Raised internally to stop the operation flow and return a failure.
    class Halt < StandardError
      # @return [Symbol] The error type.
      attr_reader :type
      # @return [Hash] Keys for message interpolation.
      attr_reader :msg_keys
      # @return [Hash] Additional error details.
      attr_reader :details
      # @return [NextStation::Result::Error] An existing error object.
      attr_reader :error

      # @param type [Symbol] The error type.
      # @param msg_keys [Hash] Keys for message interpolation.
      # @param details [Hash] Additional error details.
      # @param error [NextStation::Result::Error] An existing error object.
      def initialize(type: nil, msg_keys: {}, details: {}, error: nil)
        @type = type
        @msg_keys = msg_keys
        @details = details
        @error = error
      end
    end

    # Defines an error with its messages and optional help URL.
    class ErrorDefinition
      # @return [Symbol] The error type.
      attr_reader :type
      # @return [Hash] Map of locales to message templates.
      attr_reader :messages
      # @return [String, nil] The help URL for this error.
      attr_reader :help_url

      # @param type [Symbol] The error type.
      def initialize(type)
        @type = type
        @messages = {}
        @help_url = nil
      end

      # Adds localized messages for the error.
      # @param hashes [Hash] A hash mapping locale symbols to message templates.
      def message(hashes)
        @messages.merge!(hashes)
      end

      # Sets or returns the help URL for the error.
      # @param url [String, nil] The URL to set.
      # @return [String, nil] The current help URL.
      def help_url(url = nil)
        return @help_url if url.nil?
        raise 'Only one help_url is allowed' if @help_url

        @help_url = url
      end

      # Validates whether the error definition is complete.
      # @raise [RuntimeError] if the English message is missing.
      def validate!
        raise "English message is required for error type: #{@type}" unless @messages[:en]
      end

      # Resolves the error message for a given language.
      # @param lang [Symbol, String]
      # @param msg_keys [Hash]
      # @return [String]
      def resolve_message(lang, msg_keys)
        template = @messages[lang.to_sym] || @messages[:en]
        template % msg_keys
      end
    end

    # DSL for defining multiple errors.
    class ErrorsDSL
      # @return [Hash<Symbol, ErrorDefinition>]
      attr_reader :definitions

      # Initializes a new ErrorsDSL.
      def initialize
        @definitions = {}
      end

      # Defines a new error type.
      # @param type [Symbol] The error type.
      # @yield [ErrorDefinition] The block to configure the error.
      def error_type(type, &block)
        definition = ErrorDefinition.new(type)
        definition.instance_eval(&block) if block_given?
        definition.validate!
        @definitions[type] = definition
      end
    end

    # Represents a node in the operation's execution graph (step or branch).
    class Node
      # @return [Symbol] The node type (:step, :branch, or :root).
      attr_reader :type
      # @return [Symbol, nil] The name of the step.
      attr_reader :name
      # @return [Hash] Execution options.
      attr_reader :options
      # @return [Array<Node>] Child nodes (for branches or root).
      attr_reader :children

      # @param type [Symbol] :step, :branch, or :root.
      # @param name [Symbol, nil] The name of the step.
      # @param options [Hash] Execution options.
      # @yield The block for branch nodes.
      def initialize(type, name = nil, options = {}, &block)
        @type = type
        @name = name
        @options = options
        @children = []
        instance_eval(&block) if block_given?
      end

      # Adds a step to the node.
      # @param name [Symbol] The method name to execute.
      # @param options [Hash] Execution options like :skip_if, :retry_if, :attempts, :delay.
      def step(name, options = {})
        @children << Node.new(:step, name, options)
      end

      # Adds a branch to the node.
      # @param condition [Proc] A proc that receives the state and returns a boolean.
      # @yield The block defining steps inside the branch.
      def branch(condition, &block)
        @children << Node.new(:branch, nil, { condition: condition }, &block)
      end
    end

    # Defines error types for the operation.
    # @yield The block defining errors via ErrorsDSL.
    def self.errors(&block)
      dsl = ErrorsDSL.new
      dsl.instance_eval(&block)
      @error_definitions ||= {}
      @error_definitions.merge!(dsl.definitions)
    end

    # @return [Hash] The registered error definitions.
    def self.error_definitions
      parent_defs = if superclass.respond_to?(:error_definitions)
                      superclass.error_definitions
                    else
                      {}
                    end
      parent_defs.merge(@error_definitions || {})
    end

    errors do
      error_type :validation do
        message en: 'One or more parameters are invalid. See validation details.',
                sp: 'Uno o más parámetros son inválidos. Ver detalles de validación.'
      end
    end

    # Defines the key in the state where the final result is stored.
    # @param key [Symbol]
    def self.result_at(key)
      @result_key = key
    end

    # @return [Symbol, nil] The key where the result is stored.
    def self.result_key
      @result_key || (superclass.result_key if superclass.respond_to?(:result_key))
    end

    # Defines a Dry::Struct schema for the result value.
    # @yield The block defining the schema.
    def self.result_schema(&block)
      require 'dry-struct'
      @result_class = Class.new(Dry::Struct, &block)
      @schema_enforced = true
    end

    # @return [Class, nil] The Dry::Struct class for the result.
    def self.result_class
      @result_class || (superclass.result_class if superclass.respond_to?(:result_class))
    end

    # Enables result schema enforcement.
    def self.enforce_result_schema
      @schema_enforced = true
    end

    # Disables result schema enforcement.
    def self.disable_result_schema
      @schema_enforced = false
    end

    # @return [Boolean] Whether schema enforcement is enabled.
    def self.schema_enforced?
      return @schema_enforced unless @schema_enforced.nil?
      return superclass.schema_enforced? if superclass.respond_to?(:schema_enforced?)

      false
    end

    # Defines the root execution block for the operation.
    # @yield The block defining steps and branches.
    def self.process(&block)
      @root = Node.new(:root, &block)
    end

    # Adds a step to the operation.
    # @param method_name [Symbol]
    # @param options [Hash]
    def self.step(method_name, options = {})
      @root ||= Node.new(:root)
      @root.step(method_name, options)
    end

    # Adds a branch to the operation.
    # @param condition [Proc]
    # @yield
    def self.branch(condition, &block)
      @root ||= Node.new(:root)
      @root.branch(condition, &block)
    end

    # @return [Array<Node>] The steps defined for the operation.
    def self.steps
      @root&.children || (superclass.steps if superclass.respond_to?(:steps)) || []
    end

    # Defines a Dry::Validation::Contract to validate the params.
    #
    # @note Future i18n support can be implemented here by checking for the 'i18n' gem:
    #   begin
    #     require 'i18n'
    #     @validation_contract_class.config.messages.backend = :i18n
    #   rescue LoadError
    #     @validation_contract_class.config.messages.backend = :yaml
    #   end
    #
    # @param contract_or_block [Class, nil] A Contract class or nil if a block is provided.
    # @yield The block defining the validation rules.
    def self.validate_with(contract_or_block = nil, &block)
      require 'dry-validation'
      @validation_contract_class = if block_given?
                                     Class.new(Dry::Validation::Contract) do
                                       config.messages.backend = :yaml
                                       config.messages.top_namespace = 'next_station_validations'
                                       config.messages.load_paths << File.expand_path('../config/errors.yml', __FILE__)
                                       instance_eval(&block)
                                     end
                                   elsif contract_or_block.is_a?(Class) && contract_or_block < Dry::Validation::Contract
                                     contract_or_block
                                   else
                                     raise ValidationError,
                                           'validate_with requires a block or a Dry::Validation::Contract class'
                                   end

      @validation_enforced = true
    end

    # @return [Class, nil] The validation contract class.
    def self.validation_contract_class
      @validation_contract_class || (if superclass.respond_to?(:validation_contract_class)
                                       superclass.validation_contract_class
                                     end)
    end

    # @return [Dry::Validation::Contract, nil] An instance of the validation contract.
    def self.validation_contract_instance
      @validation_contract_instance ||= validation_contract_class&.new
    end

    # Forces validation even if not explicitly defined in steps.
    def self.force_validation!
      @validation_enforced = true
    end

    # Skips validation even if defined.
    def self.skip_validation!
      @validation_enforced = false
    end

    # @return [Boolean] Whether validation is enforced.
    def self.validation_enforced?
      return @validation_enforced unless @validation_enforced.nil?

      superclass.respond_to?(:validation_enforced?) ? superclass.validation_enforced? : false
    end

    # Checks if a step exists in the operation.
    # @param name [Symbol]
    # @param nodes [Array<Node>]
    # @return [Boolean]
    def self.has_step?(name, nodes = steps)
      nodes.any? do |node|
        node.name == name || (node.type == :branch && has_step?(name, node.children))
      end
    end

    # Defines dependencies for the operation.
    # @param deps [Hash] A mapping of dependency names to values or Procs.
    def self.depends(deps)
      @dependencies = dependencies.merge(deps)
    end

    # @return [Hash] The defined dependencies.
    def self.dependencies
      @dependencies || (superclass.respond_to?(:dependencies) ? superclass.dependencies : {})
    end

    # @example Example usage, simple initialization:
    #   CreateUser.new
    # Use ` .new(deps: ...) ` to inject dependencies (e.g. test doubles).
    # @example Example usage, `.new` with override of dependencies:
    #   # Assuming Mailer is a class that sends emails:
    #   # class CreateUser < NextStation::Operation
    #   #   depends mailer: -> { Mailer.new }
    #   #   # rest of the class definition
    #   # end
    #   #
    #   # You can then inject the mock mailer in tests:
    #   mock_mailer = mock('mailer')
    #   CreateUser.new(deps: { mailer: mock_mailer })
    # @param deps [Hash] Allows to override the default dependencies.
    def initialize(deps: {})
      @injected_deps = deps
      @resolved_deps = {}
    end

    # Resolves a dependency by name.
    # @param name [Symbol]
    # @return [Object] The resolved dependency.
    def dependency(name)
      return @resolved_deps[name] if @resolved_deps.key?(name)

      if @injected_deps.key?(name)
        @resolved_deps[name] = @injected_deps[name]
      else
        default = self.class.dependencies.fetch(name)
        @resolved_deps[name] = default.is_a?(Proc) ? default.call : default
      end
    end

    # Executes the operation.
    # @param params [Hash] Input parameters.
    # @param context [Hash] Execution context (e.g. :lang).
    # @example operation.call(name: 'john', age: 25)
    # @example operation.call(params: { name: 'john', age: 25 }, context: { lang: :en })
    # @return [NextStation::Result]
    def call(params = {}, context = {})
      if self.class.validation_enforced? && !self.class.has_step?(:validation)
        raise ValidationError, 'Validation is enforced but step :validation is missing from process block'
      end

      @state = State.new(params, context)
      lang = context[:lang] || :en

      begin
        @state = execute_nodes(self.class.steps, @state)
      rescue Halt => e
        return Result::Failure.new(e.error) if e.error

        definition = self.class.error_definitions[e.type]
        raise "Undeclared error type: #{e.type}" unless definition

        message = definition.resolve_message(lang, e.msg_keys)
        return Result::Failure.new(
          Result::Error.new(
            type: e.type,
            message: message,
            help_url: definition.help_url,
            details: e.details,
            msg_keys: e.msg_keys
          )
        )
      rescue NextStation::ValidationError => e
        raise e
      rescue NextStation::Error => e
        raise e
      rescue StandardError => e
        return Result::Failure.new(
          Result::Error.new(
            type: :exception,
            message: e.message,
            details: { backtrace: e.backtrace }
          )
        )
      end

      key = self.class.result_key || :result
      unless @state.key?(key)
        raise NextStation::MissingResultKeyError, "Missing result key #{key.inspect} in state. " \
                                                 'Operations must set this key or use result_at to specify another one.'
      end

      Result::Success.new(
        @state[key],
        schema: self.class.result_class,
        enforced: self.class.schema_enforced?
      )
    end

    # Built-in step for performing validation.
    # @param state [NextStation::State]
    # @return [NextStation::State]
    def validation(state)
      contract_class = self.class.validation_contract_class
      raise ValidationError, 'Step :validation called but no contract defined via validate_with' unless contract_class

      return state unless self.class.validation_enforced?

      lang = state.context[:lang] || :en
      contract = self.class.validation_contract_instance
      result = contract.call(state.params)

      if result.success?
        state[:params] = result.to_h
        state
      else
        # Attempt to get localized errors from dry-validation, fallback to default if it fails
        # (e.g. if I18n is not configured for that language in dry-validation)
        validation_errors = begin
          result.errors(locale: lang).to_h
        rescue StandardError
          result.errors.to_h
        end

        error!(
          type: :validation,
          msg_keys: { errors: validation_errors }.merge(state.params),
          details: validation_errors
        )
      end
    end

    # Halts the operation and returns a failure result.
    # @param type [Symbol]
    # @param msg_keys [Hash]
    # @param details [Hash]
    def error!(type:, msg_keys: {}, details: {})
      raise Halt.new(type: type, msg_keys: msg_keys, details: details)
    end

    # Calls another operation and integrates its result into the current state.
    # @param state [NextStation::State]
    # @param operation_class [Class, Object] The operation to call.
    # @param with_params [Hash, Proc] Params for the child operation.
    # @param store_result_in_key [Symbol, nil] Where to store the child's result value.
    # @return [NextStation::State]
    def call_operation(state, operation_class, with_params:, store_result_in_key: nil)
      params = with_params.is_a?(Proc) ? with_params.call(state) : with_params

      operation = if operation_class.is_a?(Class)
                    operation_class.new(deps: @injected_deps)
                  else
                    operation_class
                  end

      result = operation.call(params, state.context)

      if result.success?
        state[store_result_in_key] = result.value if store_result_in_key
        state
      else
        child_error = result.error
        raise Halt.new(error: child_error) unless self.class.error_definitions.key?(child_error.type)

        error!(
          type: child_error.type,
          msg_keys: child_error.msg_keys,
          details: child_error.details
        )

      end
    end

    private

    def execute_nodes(nodes, state)
      nodes.reduce(state) do |current_state, node|
        execute_node(node, current_state)
      end
    end

    def execute_node(node, state)
      case node.type
      when :step
        execute_step(node, state)
      when :branch
        execute_branch(node, state)
      else
        state
      end
    end

    def execute_step(node, state)
      skip_condition = node.options[:skip_if]
      return state if skip_condition&.call(state)

      retry_if = node.options[:retry_if]
      max_attempts = node.options[:attempts] || 1
      delay = node.options[:delay] || 0
      attempts = 0

      loop do
        attempts += 1
        state.set_step_attempt(attempts)
        begin
          result = send(node.name, state)

          unless result.is_a?(NextStation::State)
            class_name = self.class.name || 'AnonymousOperation'
            raise NextStation::StepReturnValueError,
                  "Step '#{node.name}' in #{class_name} must return a NextStation::State object, but it returned #{result.class} (#{result.inspect})."
          end

          if retry_if && attempts < max_attempts && retry_if.call(result, nil)
            sleep(delay) if delay.positive?
            next
          end

          return result
        rescue StandardError => e
          raise e unless retry_if && attempts < max_attempts && retry_if.call(state, e)

          sleep(delay) if delay.positive?
          next
        end
      end
    end

    def execute_branch(node, state)
      condition = node.options[:condition]
      if condition.call(state)
        execute_nodes(node.children, state)
      else
        state
      end
    end
  end
end
