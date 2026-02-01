require "forwardable"

module NextStation
  class State
    extend Forwardable
    def_delegators :@data, :[], :[]=, :fetch, :key?, :has_key?, :to_h, :merge, :merge!

    attr_reader :context

    def initialize(params = {}, context = {})
      @context = context.dup.freeze
      @data = { params: unwrap_params(params).dup }
    end

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
  end
end
