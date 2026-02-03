module NextStation
  class Operation
    class Halt < StandardError
      attr_reader :type, :msg_keys, :details, :error

      def initialize(type: nil, msg_keys: {}, details: {}, error: nil)
        @type = type
        @msg_keys = msg_keys
        @details = details
        @error = error
      end
    end

    class ErrorDefinition
      attr_reader :type, :messages, :help_url

      def initialize(type)
        @type = type
        @messages = {}
        @help_url = nil
      end

      def message(hashes)
        @messages.merge!(hashes)
      end

      def help_url(url = nil)
        return @help_url if url.nil?
        raise "Only one help_url is allowed" if @help_url
        @help_url = url
      end

      def validate!
        raise "English message is required for error type: #{@type}" unless @messages[:en]
      end

      def resolve_message(lang, msg_keys)
        template = @messages[lang.to_sym] || @messages[:en]
        template % msg_keys
      end
    end

    class ErrorsDSL
      attr_reader :definitions

      def initialize
        @definitions = {}
      end

      def error_type(type, &block)
        definition = ErrorDefinition.new(type)
        definition.instance_eval(&block) if block_given?
        definition.validate!
        @definitions[type] = definition
      end
    end

    class Node
      attr_reader :type, :name, :options, :children

      def initialize(type, name = nil, options = {}, &block)
        @type = type
        @name = name
        @options = options
        @children = []
        instance_eval(&block) if block_given?
      end

      def step(name, options = {})
        @children << Node.new(:step, name, options)
      end

      def branch(condition, &block)
        @children << Node.new(:branch, nil, { condition: condition }, &block)
      end
    end

    def self.errors(&block)
      dsl = ErrorsDSL.new
      dsl.instance_eval(&block)
      @error_definitions = dsl.definitions
    end

    def self.error_definitions
      @error_definitions || (superclass.error_definitions if superclass.respond_to?(:error_definitions)) || {}
    end

    def self.result_at(key)
      @result_key = key
    end

    def self.result_key
      @result_key || (superclass.result_key if superclass.respond_to?(:result_key))
    end

    def self.result_schema(&block)
      require "dry-struct"
      @result_class = Class.new(Dry::Struct, &block)
      @schema_enforced = true
    end

    def self.result_class
      @result_class || (superclass.result_class if superclass.respond_to?(:result_class))
    end

    def self.enforce_result_schema
      @schema_enforced = true
    end

    def self.disable_result_schema
      @schema_enforced = false
    end

    def self.schema_enforced?
      return @schema_enforced unless @schema_enforced.nil?
      return superclass.schema_enforced? if superclass.respond_to?(:schema_enforced?)
      false
    end

    def self.process(&block)
      @root = Node.new(:root, &block)
    end

    def self.step(method_name, options = {})
      @root ||= Node.new(:root)
      @root.step(method_name, options)
    end

    def self.branch(condition, &block)
      @root ||= Node.new(:root)
      @root.branch(condition, &block)
    end

    def self.steps
      @root&.children || (superclass.steps if superclass.respond_to?(:steps)) || []
    end

    def self.depends(deps)
      @dependencies = dependencies.merge(deps)
    end

    def self.dependencies
      @dependencies || (superclass.respond_to?(:dependencies) ? superclass.dependencies : {})
    end

    def initialize(deps: {})
      @injected_deps = deps
      @resolved_deps = {}
    end

    def dependency(name)
      return @resolved_deps[name] if @resolved_deps.key?(name)

      if @injected_deps.key?(name)
        @resolved_deps[name] = @injected_deps[name]
      else
        default = self.class.dependencies.fetch(name)
        @resolved_deps[name] = default.is_a?(Proc) ? default.call : default
      end
    end

    def call(params = {}, context = {})
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
      rescue NextStation::Error => e
        raise e
      rescue => e
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
                                                 "Operations must set this key or use result_at to specify another one."
      end

      Result::Success.new(
        @state[key],
        schema: self.class.result_class,
        enforced: self.class.schema_enforced?
      )
    end

    def error!(type:, msg_keys: {}, details: {})
      raise Halt.new(type: type, msg_keys: msg_keys, details: details)
    end

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
        if self.class.error_definitions.key?(child_error.type)
          error!(
            type: child_error.type,
            msg_keys: child_error.msg_keys,
            details: child_error.details
          )
        else
          raise Halt.new(error: child_error)
        end
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
      return state if skip_condition && skip_condition.call(state)

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
            class_name = self.class.name || "AnonymousOperation"
            raise NextStation::StepReturnValueError, "Step '#{node.name}' in #{class_name} must return a NextStation::State object, but it returned #{result.class} (#{result.inspect})."
          end

          if retry_if && attempts < max_attempts && retry_if.call(result, nil)
            sleep(delay) if delay > 0
            next
          end

          return result
        rescue => e
          if retry_if && attempts < max_attempts && retry_if.call(state, e)
            sleep(delay) if delay > 0
            next
          else
            raise e
          end
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
