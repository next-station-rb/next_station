# frozen_string_literal: true

module NextStation
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
  end
end
