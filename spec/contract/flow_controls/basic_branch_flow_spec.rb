# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'BasicBranchFlow' do
  describe '#call' do
    class BasicBranchFlow < NextStation::Operation
      result_at :result
      process do
        step :initialize_result
        branch ->(state) { state.params[:is_admin] } do
          step :grant_admin_privileges
          step :log_admin_action
        end
        step :final_step
      end

      def initialize_result(state)
        state[:result] = { privileges_granted: false }
        state
      end

      def grant_admin_privileges(state)
        state[:result][:privileges_granted] = true
        state
      end

      def log_admin_action(state)
        state[:result][:privileges_logged] = true
        state
      end

      def final_step(state)
        state
      end
    end

    it 'Use branch to execute a group of steps only when a condition is met' do
      op = BasicBranchFlow.new.call({ is_admin: true })
      expect(op.value[:privileges_granted]).to be true
      expect(op.value[:privileges_logged]).to be true
    end

    it 'Do not use branch to execute a group of steps when a condition is not met' do
      op = BasicBranchFlow.new.call({ is_admin: false })
      expect(op.value[:privileges_granted]).to be false
      expect(op.value[:privileges_logged]).to be nil
    end
  end
end
