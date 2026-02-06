# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Basic Flow' do
  # Define the operation inside the spec
  class SuccessWithDefaultKey < NextStation::Operation
    process do
      step :notify_admin
    end

    def notify_admin(state)
      state[:result] = { hello: state.params[:name] }
      state
    end
  end

  describe '#call' do
    it 'result.success? should return the value of state[:result] if no custom result_at specified' do
      result = SuccessWithDefaultKey.new.call(name: 'John')

      expect(result.success?).to be true
      expect(result.value).to eq(hello: 'John')
      # Ensure that failed is not filled when success
      expect(result.failure?).to be false
      expect(result.error).to be_nil
    end
  end
end
