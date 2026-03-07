# frozen_string_literal: true

require 'spec_helper'

RSpec.describe NextStation::Logging::Formatter::Console do
  subject(:formatter) { described_class.new }

  let(:severity) { 'INFO' }
  let(:datetime) { Time.new(2026, 3, 6, 21, 27, 0) }
  let(:progname) { 'test_app' }
  let(:message) { 'Test message' }
  let(:msg_hash) { { message: message, operation: 'MyOperation' } }

  describe '#call' do
    context 'with a string message' do
      it 'formats the message correctly' do
        result = formatter.call(severity, datetime, progname, message)
        expect(result).to include("\e[32mI\e[0m")
        expect(result).to include('[2026-03-06 21:27:00]')
        expect(result).to include('-- Test message')
        expect(result).to end_with("\n")
      end
    end

    context 'with a hash message' do
      it 'includes operation name in blue' do
        result = formatter.call(severity, datetime, progname, msg_hash)
        expect(result).to include("\e[34mMyOperation\e[0m")
      end

      it 'includes step name in gray when present' do
        msg = msg_hash.merge(step_name: 'my_step')
        result = formatter.call(severity, datetime, progname, msg)
        expect(result).to include("\e[90m/my_step\e[0m")
      end

      it 'includes payload when present and not empty' do
        msg = msg_hash.merge(payload: { user_id: 123 })
        result = formatter.call(severity, datetime, progname, msg)
        expect(result).to include('{user_id: 123}')
      end

      it 'does not include empty payload' do
        msg = msg_hash.merge(payload: {})
        result = formatter.call(severity, datetime, progname, msg)
        expect(result).not_to include('{}')
      end
    end

    describe 'severities' do
      {
        'DEBUG' => "\e[36mD\e[0m",
        'INFO'  => "\e[32mI\e[0m",
        'WARN'  => "\e[33mW\e[0m",
        'ERROR' => "\e[31mE\e[0m",
        'FATAL' => "\e[35mF\e[0m"
      }.each do |sev, expected|
        it "formats #{sev} correctly" do
          result = formatter.call(sev, datetime, progname, message)
          expect(result).to include(expected)
        end
      end
    end

    it 'handles non-hash and non-string messages' do
      result = formatter.call(severity, datetime, progname, 123)
      expect(result).to include('-- 123')
    end
  end
end
