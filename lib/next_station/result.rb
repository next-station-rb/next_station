module NextStation
  class Result
    def success?
      false
    end

    def failure?
      false
    end

    def value
      nil
    end

    def error
      nil
    end

    class Success < Result
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

    class Failure < Result
      attr_reader :error

      def initialize(error)
        @error = error
      end

      def failure?
        true
      end
    end

    class Error
      attr_reader :type, :message, :help_url, :details, :msg_keys

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
