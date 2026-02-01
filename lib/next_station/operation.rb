module NextStation
  class Operation
    class Halt < StandardError
      attr_reader :type, :msg_keys, :details
      def initialize(type:, msg_keys: {}, details: {})
        @type = type
        @msg_keys = msg_keys
        @details = details
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
      @error_definitions || {}
    end

    def self.result_at(key)
      @result_key = key
    end

    def self.result_key
      @result_key
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
      @root&.children || []
    end

    def call(params = {}, context = {})
      @state = State.new(params, context)
      lang = context[:lang] || :en

      begin
        @state = execute_nodes(self.class.steps, @state)
      rescue Halt => e
        definition = self.class.error_definitions[e.type]
        raise "Undeclared error type: #{e.type}" unless definition

        message = definition.resolve_message(lang, e.msg_keys)
        return Result::Failure.new(
          Result::Error.new(
            type: e.type,
            message: message,
            help_url: definition.help_url,
            details: e.details
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

      Result::Success.new(@state[key])
    end

    def error!(type:, msg_keys: {}, details: {})
      raise Halt.new(type: type, msg_keys: msg_keys, details: details)
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

      result = send(node.name, state)

      unless result.is_a?(NextStation::State)
        class_name = self.class.name || "AnonymousOperation"
        raise NextStation::StepReturnValueError, "Step '#{node.name}' in #{class_name} must return a NextStation::State object, but it returned #{result.class} (#{result.inspect})."
      end

      result
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
