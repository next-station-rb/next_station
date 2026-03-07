# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe 'NextStation Logging Verbosity' do
  let(:output) { StringIO.new }
  let(:logger) { Logger.new(output) }

  before do
    # Ensure environment is not development to avoid Console formatter in tests that expect JSON
    allow(NextStation.config.environment).to receive(:development?).and_return(false)

    # Reset configuration before each test
    logger.formatter = NextStation::Logging::Formatter::Json.new
    NextStation.config.logger = logger
    
    # Fully reset the monitor to ensure test isolation
    monitor = Dry::Monitor::Notifications.new(:next_station)
    monitor.register_event('operation.start')
    monitor.register_event('operation.stop')
    monitor.register_event('step.start')
    monitor.register_event('step.stop')
    monitor.register_event('step.retry')
    monitor.register_event('log.custom')
    NextStation.config.monitor = monitor

    # Setup subscribers for this new monitor instance
    NextStation::Logging.setup!(monitor)
  end

  class VerbosityOperation < NextStation::Operation
    process do
      step :first_step
      step :flaky_step, attempts: 2, retry_if: ->(_state, _error) { true }
    end

    def first_step(state)
      state
    end

    def flaky_step(state)
      if state.step_attempt == 1
        raise 'fail'
      else
        state[:result] = 'success'
        state
      end
    end
  end

  context 'with default logging_level (:info)' do
    before do
      NextStation.config.logging_level = :info
    end

    it 'logs operation events and retries, but not step lifecycle events' do
      VerbosityOperation.new.call
      output.rewind
      log_lines = output.read.split("\n")
      logs = log_lines.map { |line| JSON.parse(line) }

      # Should have operation.start, operation.stop, and step.retry
      expect(logs.map { |l| l.dig('origin', 'event') }).to include('operation.start', 'operation.stop', 'step.retry')
      
      # Should NOT have step.start or step.stop
      expect(logs.map { |l| l.dig('origin', 'event') }).to_not include('step.start', 'step.stop')
    end
  end

  context 'with logging_level set to :debug' do
    before do
      NextStation.config.logging_level = :debug
    end

    it 'logs everything, including step lifecycle events' do
      VerbosityOperation.new.call
      output.rewind
      log_lines = output.read.split("\n")
      logs = log_lines.map { |line| JSON.parse(line) }

      # Should have all events
      events = logs.map { |l| l.dig('origin', 'event') }
      expect(events).to include('operation.start', 'operation.stop', 'step.retry', 'step.start', 'step.stop')
      
      # Verify multiple step.start events (one for first_step, two for flaky_step)
      step_starts = logs.select { |l| l.dig('origin', 'event') == 'step.start' }
      expect(step_starts.size).to eq(3) 
      
      # first_step, flaky_step (attempt 1), flaky_step (attempt 2)
      expect(step_starts.map { |l| l.dig('origin', 'step_name') }).to eq(['first_step', 'flaky_step', 'flaky_step'])

      # Verify severity level is DEBUG for step.start and step.stop
      expect(step_starts.all? { |l| l['level'] == 'DEBUG' }).to be true
      
      step_stops = logs.select { |l| l.dig('origin', 'event') == 'step.stop' }
      expect(step_stops.all? { |l| l['level'] == 'DEBUG' }).to be true

      # Operation events should still be INFO
      op_start = logs.find { |l| l.dig('origin', 'event') == 'operation.start' }
      expect(op_start['level']).to eq('INFO')
    end
  end
end
