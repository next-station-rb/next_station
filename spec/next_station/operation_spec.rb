# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NextStation::Operation do
  let(:test_operation_class) do
    Class.new(NextStation::Operation) do
      result_at :final_data

      process do
        step :first_step
        step :second_step
      end

      def first_step(state)
        state[:first] = true
        state
      end

      def second_step(state)
        state[:final_data] = { success: true }
        state
      end
    end
  end

  let(:operation) { test_operation_class.new }

  describe '.process' do
    it 'registers steps' do
      expect(test_operation_class.steps.map(&:name)).to eq(%i[first_step second_step])
    end
  end

  describe '.result_at' do
    it 'sets the result key' do
      expect(test_operation_class.result_key).to eq(:final_data)
    end
  end

  describe '#call' do
    it 'executes steps in order and returns the result at specified key' do
      result = operation.call(some_param: 'value')

      expect(result).to be_success
      expect(result.value).to eq({ success: true })
    end

    it 'passes params and context to the state' do
      op_class = Class.new(NextStation::Operation) do
        result_at :res
        process { step :check_state }
        def check_state(state)
          state[:params_ok] = (state.params[:p] == 1)
          state[:context_ok] = (state.context[:c] == 2)
          state[:res] = { params_ok: state[:params_ok], context_ok: state[:context_ok] }
          state
        end
      end

      result = op_class.new.call({ p: 1 }, { c: 2 })
      expect(result.value[:params_ok]).to be true
      expect(result.value[:context_ok]).to be true
    end

    context 'when no result_at is specified' do
      it 'returns the value at :result key' do
        op_class = Class.new(NextStation::Operation) do
          process { step :work }
          def work(state)
            state[:result] = 'Done'
            state
          end
        end
        result = op_class.new.call
        expect(result.value).to eq('Done')
      end

      it 'raises error if :result key is missing' do
        op_class = Class.new(NextStation::Operation) do
          process { step :work }
          def work(state)
            state[:done] = true
            state
          end
        end
        expect { op_class.new.call }.to raise_error(NextStation::Error, /Missing result key :result/)
      end
    end

    context 'when a step fails' do
      let(:failing_op_class) do
        Class.new(NextStation::Operation) do
          process { step :fail_now }
          def fail_now(_state)
            raise 'Boom!'
          end
        end
      end

      it 'returns a failure result with error details' do
        result = failing_op_class.new.call
        expect(result).to be_failure
        expect(result.error.type).to eq(:exception)
        expect(result.error.message).to eq('Boom!')
        expect(result.error.details[:backtrace]).not_to be_empty
      end
    end
  end
end
