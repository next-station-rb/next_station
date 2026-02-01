# frozen_string_literal: true

require "spec_helper"

RSpec.describe 'SkipStepFlow' do
  describe "#call" do
    it "skip a step conditionally using skip_if" do
      class SkipStepFLow < NextStation::Operation

        process do
          step :initialize_result
          step :send_notification, skip_if: ->(state) { state.params[:do_not_contact] }
        end

        def initialize_result(state)
          state[:result] = { contacted: false }
          state
        end

        def send_notification(state)
          state[:result] = { contacted: true }
          state
        end
      end

      op = SkipStepFLow.new.call({do_not_contact: true})
      expect(op.value[:contacted]).to be false
    end
  end
end
