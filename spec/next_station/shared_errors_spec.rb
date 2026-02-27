# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NextStation::Errors do
  let(:shared_errors_class) do
    Class.new(NextStation::Errors) do
      error_type :not_found do
        message en: 'Resource not found', sp: 'Recurso no encontrado'
      end

      error_type :unauthorized do
        message en: 'Unauthorized access'
      end
    end
  end

  let(:operation_class) do
    source = shared_errors_class
    Class.new(NextStation::Operation) do
      errors source

      errors do
        error_type :custom_error do
          message en: 'Custom error message'
        end

        # Override shared error
        error_type :not_found do
          message en: 'Specific resource not found'
        end
      end

      process do
        step :fail_not_found
      end

      def fail_not_found(state)
        error!(type: :not_found)
      end
    end
  end

  it 'imports errors from an external source' do
    expect(operation_class.error_definitions.keys).to include(:unauthorized, :custom_error, :not_found)
  end

  it 'allows overriding shared errors' do
    not_found_def = operation_class.error_definitions[:not_found]
    expect(not_found_def.messages[:en]).to eq('Specific resource not found')
  end

  it 'preserves shared errors that were not overridden' do
    unauthorized_def = operation_class.error_definitions[:unauthorized]
    expect(unauthorized_def.messages[:en]).to eq('Unauthorized access')
  end

  it 'works in practice within an operation' do
    result = operation_class.new.call
    expect(result).to be_failure
    expect(result.error.type).to eq(:not_found)
    expect(result.error.message).to eq('Specific resource not found')
  end
end
