# frozen_string_literal: true

module NextStation
  class Operation

    # The `ClassMethods` module provides a set of class-level methods for
    # defining the structure, validation, dependencies, and processing logic
    # of an operation. It introduces a DSL for custom error handling, step
    # management, schema enforcement, and parameter validation.
    #
    # === Error Handling
    # - Allows defining custom error types for the operation using a DSL.
    #
    # === Result Management
    # - Supports setting and retrieving the key where the operation result
    #   is stored.
    # - Enables schema enforcement for result values using a Dry::Struct schema.
    #
    # === Steps and Branches
    # - Facilitates defining execution steps and branches within an operation.
    # - Allows querying the presence of specific steps within the operation.
    #
    # === Validation
    # - Provides integration with Dry::Validation for validating operation parameters.
    # - Enables enforcing or skipping validation on demand.
    #
    # === Dependencies
    # - Supports defining and managing dependencies for the operation.
    #
    # === Methods
    # - {#errors}: Defines custom error types using an error DSL.
    # - {#error_definitions}: Returns all defined error mappings.
    # - {#result_at}: Defines the key in the state for the operation result.
    # - {#result_key}: Retrieves the key where the operation result is stored.
    # - {#result_schema}: Defines a schema for the result using Dry::Struct.
    # - {#result_class}: Retrieves the Dry::Struct class for the result schema.
    # - {#enforce_result_schema}: Enables schema enforcement for the result.
    # - {#disable_result_schema}: Disables schema enforcement for the result.
    # - {#schema_enforced?}: Checks if schema enforcement is enabled.
    # - {#process}: Defines the root execution block for the operation.
    # - {#step}: Adds a single execution step to the operation.
    # - {#branch}: Adds a conditional branch to the operation's execution path.
    # - {#steps}: Returns the defined execution steps for the operation.
    # - {#validate_with}: Defines validation rules using Dry::Validation.
    # - {#validation_contract_class}: Retrieves the validation contract class.
    # - {#validation_contract_instance}: Returns an instance of the
    #   validation contract.
    # - {#force_validation!}: Forces validation to be applied, even if not part
    #   of the operation steps.
    # - {#skip_validation!}: Skips validation for the operation.
    # - {#validation_enforced?}: Checks if validation is enforced.
    # - {#has_step?}: Checks the presence of a specific step in the operation.
    # - {#depends}: Defines dependencies required by the operation.
    # - {#dependencies}: Retrieves the defined dependencies.
    module ClassMethods
      # Defines error types for the operation.
      # @param external_source [Class, nil] An external error collection class.
      # @yield The block defining errors via ErrorsDSL.
      def errors(external_source = nil, &block)
        @error_definitions ||= {}

        # 1. Handle external source (e.g., SharedErrors < NextStation::Errors)
        if external_source.respond_to?(:definitions)
          @error_definitions.merge!(external_source.definitions)
        end

        # 2. Handle inline block
        if block_given?
          dsl = ErrorsDSL.new
          dsl.instance_eval(&block)
          @error_definitions.merge!(dsl.definitions)
        end
      end

      # @return [Hash] The registered error definitions.
      def error_definitions
        parent_defs = if superclass.respond_to?(:error_definitions)
                        superclass.error_definitions
                      else
                        {}
                      end
        parent_defs.merge(@error_definitions || {})
      end

      # Defines the key in the state where the final result is stored.
      # @param key [Symbol]
      def result_at(key)
        @result_key = key
      end

      # @return [Symbol, nil] The key where the result is stored.
      def result_key
        @result_key || (superclass.result_key if superclass.respond_to?(:result_key))
      end

      # Defines a Dry::Struct schema for the result value.
      # @param struct_class [Class, nil] A Dry::Struct class or nil if a block is provided.
      # @yield The block defining the schema.
      def result_schema(struct_class = nil, &block)
        require 'dry-struct'

        if @result_class
          raise NextStation::DoubleResultSchemaError, 'result_schema has already been defined'
        end

        if struct_class && block_given?
          raise NextStation::DoubleResultSchemaError, 'result_schema accepts either a Dry::Struct class OR a block, but not both.'
        end

        if struct_class
          if struct_class.is_a?(Class) && struct_class < Dry::Struct
            @result_class = struct_class
          else
            raise ArgumentError, 'result_schema requires a subclass of Dry::Struct'
          end
        elsif block_given?
          @result_class = Class.new(Dry::Struct, &block)
          const_set(:ResultSchema, @result_class) unless const_defined?(:ResultSchema, false)
        else
          raise ArgumentError, 'result_schema requires either a Dry::Struct class or a block'
        end

        @schema_enforced = true
      end

      # @return [Class, nil] The Dry::Struct class for the result.
      def result_class
        @result_class || (superclass.result_class if superclass.respond_to?(:result_class))
      end

      # Enables result schema enforcement.
      def enforce_result_schema
        @schema_enforced = true
      end

      # Disables result schema enforcement.
      def disable_result_schema
        @schema_enforced = false
      end

      # @return [Boolean] Whether schema enforcement is enabled.
      def schema_enforced?
        return @schema_enforced unless @schema_enforced.nil?
        return superclass.schema_enforced? if superclass.respond_to?(:schema_enforced?)

        false
      end

      # Defines the root execution block for the operation.
      # @yield The block defining steps and branches.
      def process(&block)
        @root = Node.new(:root, &block)
      end

      # Adds a step to the operation.
      # @param method_name [Symbol]
      # @param options [Hash]
      def step(method_name, options = {})
        @root ||= Node.new(:root)
        @root.step(method_name, options)
      end

      # Adds a branch to the operation.
      # @param condition [Proc]
      # @yield
      def branch(condition, &block)
        @root ||= Node.new(:root)
        @root.branch(condition, &block)
      end

      # @return [Array<Node>] The steps defined for the operation.
      def steps
        @root&.children || (superclass.steps if superclass.respond_to?(:steps)) || []
      end

      # Defines a Dry::Validation::Contract to validate the params.
      #
      # @param contract_or_block [Class, nil] A Contract class or nil if a block is provided.
      # @yield The block defining the validation rules.
      def validate_with(contract_or_block = nil, &block)
        require 'dry-validation'
        @validation_contract_class = if block_given?
                                       Class.new(Dry::Validation::Contract) do
                                         config.messages.backend = :yaml
                                         config.messages.top_namespace = 'next_station_validations'
                                         config.messages.load_paths << File.expand_path('../../config/errors.yml', __FILE__)
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
      def validation_contract_class
        @validation_contract_class || (if superclass.respond_to?(:validation_contract_class)
                                         superclass.validation_contract_class
                                       end)
      end

      # @return [Dry::Validation::Contract, nil] An instance of the validation contract.
      def validation_contract_instance
        @validation_contract_instance ||= validation_contract_class&.new
      end

      # Forces validation even if not explicitly defined in steps.
      def force_validation!
        @validation_enforced = true
      end

      # Skips validation even if defined.
      def skip_validation!
        @validation_enforced = false
      end

      # @return [Boolean] Whether validation is enforced.
      def validation_enforced?
        return @validation_enforced unless @validation_enforced.nil?

        superclass.respond_to?(:validation_enforced?) ? superclass.validation_enforced? : false
      end

      # Checks if a step exists in the operation.
      # @param name [Symbol]
      # @param nodes [Array<Node>]
      # @return [Boolean]
      def has_step?(name, nodes = steps)
        nodes.any? do |node|
          node.name == name || (node.type == :branch && has_step?(name, node.children))
        end
      end

      # Defines dependencies for the operation.
      # @param deps [Hash] A mapping of dependency names to values or Procs.
      # @example depends mailer: -> { Mailer.new }
      # @example depends repository: UserRepository.new
      # @example Usage inside a step:
      #   def send_email
      #     # Access dependencies using the dependency() method
      #     dependency(:mailer).send_welcome(state.params[:email])
      #     # rest of the step
      #   end
      #
      # @example You can override the dependencies when instantiating the operation by passing the deps: argument:
      #   mock_mailer = double("Mailer")
      #   operation = CreateUser.new(deps: { mailer: mock_mailer })
      #   operation.call(email: "test@example.com")
      def depends(deps)
        @dependencies = dependencies.merge(deps)
      end

      # @return [Hash] The defined dependencies.
      def dependencies
        @dependencies || (superclass.respond_to?(:dependencies) ? superclass.dependencies : {})
      end
    end
  end
end
