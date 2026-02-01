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
      attr_reader :value

      def initialize(value)
        @value = value
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
      attr_reader :type, :message, :help_url, :details

      def initialize(type:, message: nil, help_url: nil, details: {})
        @type = type
        @message = message
        @help_url = help_url
        @details = details
      end
    end
  end
end
