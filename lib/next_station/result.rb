module NextStation
  # Represents the result of an operation.
  class Result
    # @return [Boolean] true if the result is a success.
    def success?
      false
    end

    # @return [Boolean] true if the result is a failure.
    def failure?
      false
    end

    # @return [Object, nil] The value of a successful result.
    def value
      nil
    end

    # @return [NextStation::Result::Error, nil] The error object if it's a failure.
    def error
      nil
    end

    # Represents a successful operation result.
    class Success < Result
      # @param value [Object] The result value.
      # @param schema [Class, nil] The Dry::Struct schema to validate against.
      # @param enforced [Boolean] Whether schema validation is enforced.
      def initialize(value, schema: nil, enforced: false)
        @raw_value = value
        @schema = schema
        @enforced = enforced
        @validated_value = nil
      end

      def value
        if @enforced && @schema.nil?
          raise NextStation::Error, "Result schema enforcement is enabled but no result_schema is defined."
        end

        return @raw_value unless @enforced && @schema

        @validated_value ||= begin
          @schema.new(@raw_value)
        rescue => e
          raise NextStation::ResultShapeError, e.message
        end
      end

      def success?
        true
      end
    end

    # Represents a failed operation result.
    class Failure < Result
      attr_reader :error

      # @param error [NextStation::Result::Error]
      def initialize(error)
        @error = error
      end

      def failure?
        true
      end
    end

    # Structured error information.
    class Error
      # @return [Symbol]
      attr_reader :type
      # @return [String, nil]
      attr_reader :message
      # @return [String, nil]
      attr_reader :help_url
      # @return [Hash]
      attr_reader :details
      # @return [Hash]
      attr_reader :msg_keys

      # @param type [Symbol]
      # @param message [String, nil]
      # @param help_url [String, nil]
      # @param details [Hash]
      # @param msg_keys [Hash]
      def initialize(type:, message: nil, help_url: nil, details: {}, msg_keys: {})
        @type = type
        @message = message
        @help_url = help_url
        @details = details
        @msg_keys = msg_keys
      end
    end
  end
end
