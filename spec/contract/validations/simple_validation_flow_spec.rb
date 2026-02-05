# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SimpleValidationFlow' do
  let(:operation_class) do
    Class.new(NextStation::Operation) do
      # 1. Define the validation rules using `dry-validation`
      validate_with do
        params do
          required(:email).filled(:string, format?: /@/)
          required(:age).filled(:integer, gteq?: 18)
        end
      end

      # 2. The process block includes the special `:validation` step
      process do
        step :validation
        step :create_user_record
      end

      # This step should only be reached if validation succeeds
      def create_user_record(state)
        # The 'age' param is now a coerced Integer
        state[:result] = {}
        state[:result][:user_created] = true
        state[:result][:age_class_after_coercion] = state.params[:age].class
        state
      end
    end
  end

  let(:operation) { operation_class.new }

  context 'when input is valid' do
    # Age is passed as a string to test coercion
    let(:valid_params) { { email: 'test@example.com', age: '21' } }

    subject(:result) { operation.call(valid_params) }

    it 'returns a Success result' do
      expect(result).to be_success
    end

    it 'executes the steps following validation' do
      # The internal state is inspected here only for testing purposes
      # to confirm that the subsequent step was executed.
      expect(result.value[:user_created]).to be true
    end

    it 'coerces the input parameters according to the contract' do
      # The :age parameter was passed as a string '21'
      # but should be an Integer after the :validation step.
      expect(result.value[:age_class_after_coercion]).to eq(Integer)
    end
  end

  context 'when input is invalid' do
    # Both email format and age are invalid
    let(:invalid_params) { { email: 'invalid-email', age: 17 } }

    subject(:result) { operation.call(invalid_params) }

    it 'returns a Failure result' do
      expect(result).to be_failure
    end

    it 'does NOT execute steps following validation' do
      # We spy on the method to ensure it's never called
      expect_any_instance_of(operation_class).not_to receive(:create_user_record)
      result
    end

    it 'returns an error of type :validation' do
      expect(result.error.type).to eq(:validation)
    end

    it 'provides validation failure details from the contract' do
      expect(result.error.details).to be_a(Hash)
      expect(result.error.details[:email]).to include('is in invalid format')
      expect(result.error.details[:age]).to include('must be greater than or equal to 18')
    end

    it 'provides a default error message for validation failures' do
      expected_message = 'One or more parameters are invalid. See validation details.'
      expect(result.error.message).to eq(expected_message)
    end
  end
end
