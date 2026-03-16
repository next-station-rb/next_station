# frozen_string_literal: true

require 'forwardable'

module NextStation
  # Holds the mutable state during operation execution.
  #
  # It wraps a data hash and provides access to params and context.
  class State
    extend Forwardable
    def_delegators :@data, :[], :[]=, :fetch, :key?, :has_key?, :to_h, :merge, :merge!

    # @return [Hash] The execution context.
    attr_reader :context
    # @return [Integer] The attempt number of the current step.
    attr_reader :step_attempt
    # @return [Symbol, nil] The name of the current step being executed.
    attr_reader :current_step

    # @param params [Hash] Initial parameters.
    # @param context [Hash] Shared context (immutable).
    def initialize(params = {}, context = {}, plugins = [])
      @context = context.dup.freeze
      @data = { params: unwrap_params(params).dup }
      @step_attempt = 1
      @current_step = nil
      extend_with_plugins(plugins)
    end

    # Sets the current attempt number for the active step.
    # @param value [Integer]
    def set_step_attempt(value)
      @step_attempt = value
    end
    
    # Sets the name of the current step.
    # @param value [Symbol, nil]
    def set_current_step(value)
      @current_step = value
    end

    # Returns the input parameters.
    # @return [Hash]
    def params
      @data[:params]
    end

    private

    def unwrap_params(params)
      if params.is_a?(Hash) && params.key?(:params) && params.keys.size == 1
        params[:params]
      else
        params
      end
    end

    def extend_with_plugins(plugins)
      plugins.each do |mod|
        extend mod::State if mod.const_defined?(:State)
      end
    end
  end
end
