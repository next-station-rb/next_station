# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Result schema Spec' do
  let(:enforced_but_not_schema_given) do
    Class.new(NextStation::Operation) do
      enforce_result_schema
      # No schema block defined

      process do
        step :set_data
      end
      def set_data(state)
        state[:result] = state.params
        state
      end
    end
  end

  let(:enforced_with_schema_given) do
    Class.new(NextStation::Operation) do
      enforce_result_schema

      result_schema do
        attribute :name, NextStation::Types::String
      end

      process do
        step :set_data
      end
      def set_data(state)
        state[:result] = {name: "A string"}
        state
      end
    end
  end

  subject(:test_enforced_but_not_schema_given) { enforced_but_not_schema_given.new.call }
  subject(:test_enforced_with_schema_given) { enforced_with_schema_given.new }

  it 'raise exception if enforced but no schema given' do
    expect(test_enforced_but_not_schema_given.success?).to be true # It's a success because dry-validation is lazily loaded on .value
    expect { test_enforced_but_not_schema_given.value }.to raise_error(NextStation::Error)
  end

  it 'Success when enforced and schema given' do
    op = test_enforced_with_schema_given.call({})
    expect(op.success?).to be true
    expect(op.value[:name]).to eq("A string")
  end
end
