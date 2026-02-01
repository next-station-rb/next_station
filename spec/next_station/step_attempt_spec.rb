require "spec_helper"

RSpec.describe "Step Attempt Visibility" do
  let(:operation_class) do
    Class.new(NextStation::Operation) do
      result_at :attempts
      process do
        step :collect_attempts,
             retry_if: ->(state, _exception) { state[:attempts].size < 3 },
             attempts: 3
      end

      def collect_attempts(state)
        state[:attempts] ||= []
        state[:attempts] << state.step_attempt
        state
      end
    end
  end

  it "tracks step_attempt correctly during retries" do
    result = operation_class.new.call
    expect(result.success?).to be true
    # The step is called 3 times. 
    # Attempt 1: collect [1], retry_if true
    # Attempt 2: collect [1, 2], retry_if true
    # Attempt 3: collect [1, 2, 3], retry_if false (attempts == 3)
    expect(result.value).to eq([1, 2, 3])
  end

  context "with exceptions" do
    let(:operation_with_exception) do
      Class.new(NextStation::Operation) do
        process do
          step :fail_then_succeed,
               retry_if: ->(_state, exception) { exception.is_a?(RuntimeError) },
               attempts: 3
        end

        def fail_then_succeed(state)
          state[:last_seen_attempt] = state.step_attempt
          if state.step_attempt < 3
            raise "Try again"
          end
          state[:result] = "Success"
          state
        end
      end
    end

    it "sets step_attempt correctly before exception occurs" do
      result = operation_with_exception.new.call
      expect(result.success?).to be true
      expect(result.value).to eq("Success")
    end
  end
end
