# frozen_string_literal: true

require 'spec_helper'
require 'dry-struct'

RSpec.describe 'Result Schema Enhancements' do
  describe 'Constant Assignment' do
    it 'assigns the ResultSchema constant when defined inline' do
      op_class = Class.new(NextStation::Operation) do
        result_schema do
          attribute :name, NextStation::Types::String
        end
      end

      expect(op_class::ResultSchema).to be_a(Class)
      expect(op_class::ResultSchema).to be < Dry::Struct
      expect(op_class::ResultSchema.attribute_names).to eq([:name])
    end

    it 'does not overwrite existing ResultSchema constant if already defined' do
      class PredefinedSchema < Dry::Struct
        attribute :id, NextStation::Types::Integer
      end

      op_class = Class.new(NextStation::Operation) do
        const_set(:ResultSchema, PredefinedSchema)
        result_schema do
          attribute :name, NextStation::Types::String
        end
      end

      expect(op_class::ResultSchema).to eq(PredefinedSchema)
      expect(op_class.result_class.attribute_names).to eq([:name])
    end
  end

  describe 'External Struct Support' do
    let(:external_struct) do
      Class.new(Dry::Struct) do
        attribute :id, NextStation::Types::Integer
        attribute :email, NextStation::Types::String
      end
    end

    it 'accepts an external Dry::Struct class' do
      struct = external_struct
      op_class = Class.new(NextStation::Operation) do
        result_schema struct
        process { step :set_data }
        def set_data(state); state[:result] = state.params; state; end
      end

      result = op_class.new.call(id: 1, email: 'test@example.com')
      expect(result.value).to be_a(struct)
      expect(result.value.id).to eq(1)
    end

    it 'raises ArgumentError if the argument is not a Dry::Struct subclass' do
      expect {
        Class.new(NextStation::Operation) do
          result_schema String
        end
      }.to raise_error(ArgumentError, /requires a subclass of Dry::Struct/)
    end
  end

  describe 'Mutual Exclusion' do
    let(:external_struct) { Class.new(Dry::Struct) }

    it 'raises NextStation::DoubleResultSchemaError if both a class and a block are provided' do
      struct = external_struct
      expect {
        Class.new(NextStation::Operation) do
          result_schema(struct) do
            attribute :foo, NextStation::Types::String
          end
        end
      }.to raise_error(NextStation::DoubleResultSchemaError, /accepts either a Dry::Struct class OR a block, but not both/)
    end

    it 'raises NextStation::DoubleResultSchemaError if result_schema is called multiple times' do
      struct = external_struct
      expect {
        Class.new(NextStation::Operation) do
          result_schema struct
          result_schema do
            attribute :name, NextStation::Types::String
          end
        end
      }.to raise_error(NextStation::DoubleResultSchemaError, /result_schema has already been defined/)
    end
  end

  describe 'Lazy Validation' do
    it 'confirms that NextStation::ResultShapeError is only raised when result.value is accessed' do
      op_class = Class.new(NextStation::Operation) do
        result_schema do
          attribute :id, NextStation::Types::Integer
        end
        process { step :set_data }
        def set_data(state); state[:result] = { id: 'invalid' }; state; end
      end

      result = op_class.new.call
      expect(result).to be_success
      expect { result.value }.to raise_error(NextStation::ResultShapeError)
    end
  end
end
