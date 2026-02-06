# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Add resilience to flaky steps using retry_if, attempts, and delay' do
  let(:operation_class) do
    Class.new(NextStation::Operation) do
      process do
        step :step_one, retry_if: ->(state, _exception) { state[:fail] }, attempts: 5, delay: 0
        step :step_two
      end

      def step_one(state)
        state[:fail] = true
        state[:result] = { attempts: state.step_attempt }
        raise('External Error') unless state.step_attempt == state.params[:retries]

        state[:fail] = false

        state
      end

      def step_two(state)
        state[:result][:step_two_executed] = true
        state
      end
    end
  end

  subject(:correct_result) { operation_class.new.call({ retries: 5 }) }
  subject(:reties_exceeded) { operation_class.new.call({ retries: 6 }) }

  it 'expect to handle correctly the last attempt' do
    # 5 is hardcoded in the :retries option, so this should handle the last attempt
    expect(correct_result.value[:attempts]).to eq(5)
    expect(correct_result.value[:step_two_executed]).to eq(true)
  end

  it 'expect to handle error after 5 attempts' do
    expect(reties_exceeded.failure?).to eq(true)
  end
end
