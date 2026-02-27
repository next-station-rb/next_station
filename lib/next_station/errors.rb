# frozen_string_literal: true

module NextStation
  class Errors
    def self.inherited(subclass)
      super
      subclass.extend(SharedErrorsDSL)
    end

    module SharedErrorsDSL
      def error_type(type, &block)
        @dsl ||= NextStation::Operation::ErrorsDSL.new
        @dsl.error_type(type, &block)
      end

      def definitions
        @dsl&.definitions || {}
      end
    end
  end
end
