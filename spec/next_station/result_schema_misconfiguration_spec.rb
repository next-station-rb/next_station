# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Result Schema Misconfiguration' do
  it 'raises an exception if enforce_result_schema is set but no result_schema is defined' do
    op_class = Class.new(NextStation::Operation) do
      enforce_result_schema

      process do
        step :set_data
      end

      def set_data(state)
        state[:result] = { some: 'data' }
        state
      end
    end

    op = op_class.new
    # The user says "operation should raise an exception"
    # It's not clear if they mean on .call or on .value
    # Given the lazy evaluation, let's check both or decide.
    # If I follow "The result contract is evaluated only on successful operations durong the call to .value",
    # then it should probably be on .value.
    # But if it's a configuration error, .call might be better.

    result = op.call
    expect { result.value }.to raise_error(NextStation::Error, /enforcement is enabled but no result_schema is defined/)
  end

  it 'still enables enforcement if enforce_result_schema is called even if it was already enabled by result_schema' do
    op_class = Class.new(NextStation::Operation) do
      result_schema do
        attribute :name, NextStation::Types::String
      end
      enforce_result_schema # explicitly called

      process { step :set_data }
      def set_data(state)
        state[:result] = { name: 123 }
        state
      end
    end

    result = op_class.new.call
    expect { result.value }.to raise_error(NextStation::ResultShapeError)
  end

  it 'inherits enforcement even without a schema' do
    parent_class = Class.new(NextStation::Operation) do
      enforce_result_schema
    end

    child_class = Class.new(parent_class) do
      process { step :work }
      def work(state)
        state[:result] = {}
        state
      end
    end

    result = child_class.new.call
    expect { result.value }.to raise_error(NextStation::Error, /enforcement is enabled but no result_schema is defined/)
  end
end
