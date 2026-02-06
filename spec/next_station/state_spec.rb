# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NextStation::State do
  let(:params) { { name: 'John', age: 30 } }
  let(:context) { { current_user_id: 1 } }
  subject { described_class.new(params, context) }

  describe '#initialize' do
    it 'sets params and context' do
      expect(subject.params).to eq(params)
      expect(subject.context).to eq(context)
    end

    it 'freezes context' do
      expect(subject.context).to be_frozen
    end

    it 'dups params and context' do
      original_params = params.dup
      original_context = context.dup

      instance = described_class.new(params, context)

      params[:foo] = :bar
      context[:baz] = :qux

      expect(instance.params).to eq(original_params)
      expect(instance.context).to eq(original_context)
    end
  end

  describe 'hash-like behavior' do
    it 'does not allow reading from params directly' do
      expect(subject[:name]).to be_nil
    end

    it 'allows reading from params via :params key' do
      expect(subject[:params][:name]).to eq('John')
    end

    it 'allows writing new values' do
      subject[:new_key] = 'new_value'
      expect(subject[:new_key]).to eq('new_value')
    end

    it 'supports fetch for added keys' do
      subject[:foo] = :bar
      expect(subject.fetch(:foo)).to eq(:bar)
    end

    it 'supports key? for params and added keys' do
      expect(subject.key?(:params)).to be true
      expect(subject.key?(:name)).to be false

      subject[:added] = true
      expect(subject.key?(:added)).to be true
    end

    it 'supports to_h' do
      subject[:added] = true
      expect(subject.to_h).to eq({ params: params, added: true })
    end
  end
end
