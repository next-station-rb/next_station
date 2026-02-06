# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'success with result at key' do
  let(:operation_class) do
    Class.new(NextStation::Operation) do
      result_at :my_custom_result

      process do
        step :notify_admin
      end

      def notify_admin(state)
        state[:my_custom_result] = { hello: state.params[:name] }
        state
      end
    end
  end

  subject(:result) { operation_class.new.call({ name: 'John' }) }

  it 'returns the custom result' do
    expect(result).to be_success
    expect(result.value).to eq(hello: 'John')
  end
end
