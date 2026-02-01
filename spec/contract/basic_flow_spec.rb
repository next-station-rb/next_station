# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Basic Flow" do
  # Define the operation inside the spec
  class BasicFlow < NextStation::Operation
    #result_at :my_result

    process do
      step :save_in_db
      step :notify_admin
    end

    def save_in_db(state)
      # simulate persistence
      state[:name] = state.params[:name]
      state
    end
    def notify_admin(state)
      state[:result] = { hello: state[:name]}
      state
    end
  end

  describe '#call' do
    context 'when everything works normally' do
      it 'result.success? to be true and result.value to be { hello: "world" }' do

        result = BasicFlow.new.call({ name: "John"} )

        expect(result.success?).to be true
        expect(result.value).to eq( { hello: "John" } )
        # Ensure that failed is not filled when success
        expect(result.failure?).to be false
        expect(result.error).to be_nil
      end
    end
  end
end