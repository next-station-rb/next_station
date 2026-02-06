# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'NextStation::Operation Retry Logic' do
  class RetryOperation < NextStation::Operation
    def self.reset_attempts
      @attempts = 0
    end

    def self.increment_attempts
      @attempts ||= 0
      @attempts += 1
    end

    def self.attempts
      @attempts || 0
    end

    process do
      step :flaky_step,
           retry_if: ->(_state, exception) { exception.is_a?(StandardError) },
           attempts: 3,
           delay: 0.01
    end

    def flaky_step(state)
      self.class.increment_attempts
      raise StandardError, 'Flaky error' if self.class.attempts < 3

      state.merge!(result: 'success')
      state
    end
  end

  before { RetryOperation.reset_attempts }

  it 'retries the step and succeeds if attempts are within limit' do
    result = RetryOperation.new.call
    expect(result).to be_success
    expect(result.value).to eq('success')
    expect(RetryOperation.attempts).to eq(3)
  end

  class FailedRetryOperation < NextStation::Operation
    def self.reset_attempts
      @attempts = 0
    end

    def self.increment_attempts
      @attempts ||= 0
      @attempts += 1
    end

    def self.attempts
      @attempts || 0
    end

    process do
      step :always_fails,
           retry_if: ->(_state, exception) { exception.is_a?(StandardError) },
           attempts: 2,
           delay: 0.01
    end

    def always_fails(_state)
      self.class.increment_attempts
      raise StandardError, 'Permanent error'
    end
  end

  before { FailedRetryOperation.reset_attempts }

  it 're-raises the exception if attempts run out' do
    result = FailedRetryOperation.new.call
    expect(result).not_to be_success
    expect(result.error.message).to eq('Permanent error')
    expect(FailedRetryOperation.attempts).to eq(2)
  end

  class ConditionRetryOperation < NextStation::Operation
    process do
      step :check_state,
           retry_if: ->(state, _exception) { state[:retry_me] == true },
           attempts: 2,
           delay: 0.01
    end

    def check_state(state)
      if state[:retry_me].nil?
        state.merge!(retry_me: true)
      else
        state.merge!(retry_me: false, result: 'finally')
      end
      state
    end
  end

  it 'retries based on state condition even if no exception is raised' do
    # NOTE: The prompt says "If the step raises an exception (or a conditional to review something in the state key)"
    # This implies that even if it doesn't raise, we might want to retry.
    # However, usually retry is for exceptions. Let's re-read:
    # "Logic: If the step raises an exception (or a conditional to review something in the state key), check retry_if."

    result = ConditionRetryOperation.new.call
    expect(result).to be_success
    expect(result.value).to eq('finally')
  end
end
