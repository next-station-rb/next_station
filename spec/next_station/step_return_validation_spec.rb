require "spec_helper"

RSpec.describe NextStation::Operation do
  it "raises a descriptive error if a step returns nil" do
    operation_class = Class.new(NextStation::Operation) do
      process { step :bad_step }
      def bad_step(_state); nil; end
    end
    
    expect {
      operation_class.new.call
    }.to raise_error(NextStation::StepReturnValueError, /Step 'bad_step' in .* must return a NextStation::State object, but it returned NilClass \(nil\)/)
  end

  it "raises a descriptive error if a step returns a non-State object (e.g. String)" do
    operation_class = Class.new(NextStation::Operation) do
      process { step :bad_step }
      def bad_step(_state); "not a state"; end
    end
    
    expect {
      operation_class.new.call
    }.to raise_error(NextStation::StepReturnValueError, /Step 'bad_step' in .* must return a NextStation::State object, but it returned String \("not a state"\)/)
  end

  it "works fine if the step returns the state" do
    operation_class = Class.new(NextStation::Operation) do
      result_at :ok
      process { step :good_step }
      def good_step(state); state[:ok] = true; state; end
    end
    
    result = operation_class.new.call
    expect(result).to be_success
    expect(result.value).to be true
  end
end
