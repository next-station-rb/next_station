# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Basic Flow' do
  describe '#call' do
    it 'result.success? should raise Exception if developer not set a result_at key or a :result' do
      class SuccessShouldReturnExceptionIfNoSuccessKey < NextStation::Operation
        process do
          step :notify_admin
        end

        def notify_admin(state)
          state
        end
      end

      op = SuccessShouldReturnExceptionIfNoSuccessKey.new
      expect { op.call({}) }.to raise_error(NextStation::Error, /Missing result key :result in state/)
    end
  end
end
