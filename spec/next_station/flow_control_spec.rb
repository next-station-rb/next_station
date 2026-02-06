# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Flow Control' do
  let(:operation_class) do
    Class.new(NextStation::Operation) do
      process do
        step :normalize_email
        step :send_notification, skip_if: ->(s) { s.params[:do_not_contact] }
        branch ->(s) { s.params[:is_admin] } do
          step :grant_admin_privileges
          step :email_ops_team
        end
        step :final_step
      end

      def normalize_email(state)
        state[:normalized] = true
        state
      end

      def send_notification(state)
        state[:notified] = true
        state
      end

      def grant_admin_privileges(state)
        state[:admin_granted] = true
        state
      end

      def email_ops_team(state)
        state[:ops_emailed] = true
        state
      end

      def final_step(state)
        state[:finished] = true
        state[:result] = state.to_h
        state
      end
    end
  end

  let(:operation) { operation_class.new }

  it 'skips a step if skip_if condition is met' do
    result = operation.call(do_not_contact: true)
    expect(result.value[:normalized]).to be true
    expect(result.value[:notified]).to be_nil
    expect(result.value[:finished]).to be true
  end

  it 'executes a step if skip_if condition is not met' do
    result = operation.call(do_not_contact: false)
    expect(result.value[:normalized]).to be true
    expect(result.value[:notified]).to be true
    expect(result.value[:finished]).to be true
  end

  it 'executes branch steps if branch condition is met' do
    result = operation.call(is_admin: true)
    expect(result.value[:admin_granted]).to be true
    expect(result.value[:ops_emailed]).to be true
    expect(result.value[:finished]).to be true
  end

  it 'skips branch steps if branch condition is not met' do
    result = operation.call(is_admin: false)
    expect(result.value[:admin_granted]).to be_nil
    expect(result.value[:ops_emailed]).to be_nil
    expect(result.value[:finished]).to be true
  end

  it 'supports nested branching (bonus/robustness check)' do
    nested_op_class = Class.new(NextStation::Operation) do
      process do
        branch ->(s) { s.params[:level1] } do
          step :step1
          branch ->(s) { s.params[:level2] } do
            step :step2
          end
        end
        step :finish
      end

      def step1(state)
        state[:s1] = true
        state
      end

      def step2(state)
        state[:s2] = true
        state
      end

      def finish(state)
        state[:result] = state.to_h
        state
      end
    end

    expect(nested_op_class.new.call(level1: true, level2: true).value[:s2]).to be true
    expect(nested_op_class.new.call(level1: true, level2: false).value[:s2]).to be_nil
    expect(nested_op_class.new.call(level1: false, level2: true).value[:s1]).to be_nil
  end
end
