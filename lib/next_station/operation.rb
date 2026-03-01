# frozen_string_literal: true

require_relative 'operation/errors'
require_relative 'operation/node'
require_relative 'operation/class_methods'

module NextStation
  # The core class for defining operations.
  #
  # Operations are composed of steps and branches, and they return a NextStation::Result.
  class Operation
    extend ClassMethods

    errors do
      error_type :validation do
        message en: 'One or more parameters are invalid. See validation details.',
                sp: 'Uno o más parámetros son inválidos. Ver detalles de validación.'
      end
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
      monitor = NextStation.config.monitor

      monitor.publish('operation.start', operation: self.class.name, params: params, context: context)

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      if self.class.validation_enforced? && !self.class.has_step?(:validation)
        raise ValidationError, 'Validation is enforced but step :validation is missing from process block'
      end

      @state = State.new(params, context)
      lang = context[:lang] || :en

      begin
        @state = execute_nodes(self.class.steps, @state)
      rescue Halt => e
        result = if e.error
                   Result::Failure.new(e.error)
                 else
                   definition = self.class.error_definitions[e.type]
                   raise "Undeclared error type: #{e.type}" unless definition

                   message = definition.resolve_message(lang, e.msg_keys)
                   Result::Failure.new(
                     Result::Error.new(
                       type: e.type,
                       message: message,
                       help_url: definition.help_url,
                       details: e.details,
                       msg_keys: e.msg_keys
                     )
                   )
                 end
        monitor.publish('operation.stop',
                        operation: self.class.name,
                        duration: duration(start_time),
                        result: result,
                        state: @state)
        return result
      rescue NextStation::ValidationError => e
        raise e
      rescue NextStation::Error => e
        raise e
      rescue StandardError => e
        result = Result::Failure.new(
          Result::Error.new(
            type: :exception,
            message: e.message,
            details: { backtrace: e.backtrace }
          )
        )
        monitor.publish('operation.stop',
                        operation: self.class.name,
                        duration: duration(start_time),
                        result: result,
                        state: @state)
        return result
      end

      key = self.class.result_key || :result
      unless @state.key?(key)
        raise NextStation::MissingResultKeyError, "Missing result key #{key.inspect} in state. " \
                                                 'Operations must set this key or use result_at to specify another one.'
      end

      result = Result::Success.new(
        @state[key],
        schema: self.class.result_class,
        enforced: self.class.schema_enforced?
      )

      monitor.publish('operation.stop',
                      operation: self.class.name,
                      duration: duration(start_time),
                      result: result,
                      state: @state)
      result
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

    # Publishes a log event to the monitor.
    # @param level [Symbol] The log level (e.g. :info, :error).
    # @param message [String] The log message.
    # @param payload [Hash] Additional metadata for the log.
    def publish_log(level, message, payload = {})
      NextStation.config.monitor.publish(
        'log.custom',
        level: level,
        message: message,
        operation: self.class.name,
        step_name: @state&.current_step,
        payload: payload
      )
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

    def duration(start_time)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
    end

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

      state.set_current_step(node.name)

      retry_if = node.options[:retry_if]
      max_attempts = node.options[:attempts] || 1
      delay = node.options[:delay] || 0
      attempts = 0
      monitor = NextStation.config.monitor

      loop do
        attempts += 1
        state.set_step_attempt(attempts)

        monitor.publish('step.start', operation: self.class.name, step: node.name, state: state, attempt: attempts)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          result = send(node.name, state)

          unless result.is_a?(NextStation::State)
            class_name = self.class.name || 'AnonymousOperation'
            raise NextStation::StepReturnValueError,
                  "Step '#{node.name}' in #{class_name} must return a NextStation::State object, but it returned #{result.class} (#{result.inspect})."
          end

          if retry_if && attempts < max_attempts && retry_if.call(result, nil)
            monitor.publish('step.retry',
                            operation: self.class.name,
                            step: node.name,
                            state: result,
                            attempt: attempts,
                            duration: duration(start_time))
            sleep(delay) if delay.positive?
            next
          end

          monitor.publish('step.stop',
                          operation: self.class.name,
                          step: node.name,
                          state: result,
                          attempt: attempts,
                          duration: duration(start_time))
          return result
        rescue StandardError => e
          if retry_if && attempts < max_attempts && retry_if.call(state, e)
            monitor.publish('step.retry',
                            operation: self.class.name,
                            step: node.name,
                            state: state,
                            attempt: attempts,
                            error: e,
                            duration: duration(start_time))
            sleep(delay) if delay.positive?
            next
          end

          monitor.publish('step.stop',
                          operation: self.class.name,
                          step: node.name,
                          state: state,
                          attempt: attempts,
                          error: e,
                          duration: duration(start_time))
          raise e
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
