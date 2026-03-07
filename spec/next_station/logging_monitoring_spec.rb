# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe 'NextStation Logging and Monitoring' do
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

  class LoggingOperation < NextStation::Operation
    process do
      step :first_step
      step :second_step
    end

    def first_step(state)
      publish_log(:info, 'First step executed', detail: 'some detail')
      state
    end

    def second_step(state)
      state[:result] = 'success'
      state
    end
  end

  it 'logs user events to the configured logger' do
    LoggingOperation.new.call
    output.rewind
    log_content = output.read
    
    # Each line is a JSON log
    logs = log_content.split("\n").map { |line| JSON.parse(line) }
    
    # Find the user log from first_step
    user_log = logs.find { |l| l['origin'] && l['origin']['event'] == 'log.custom' && l['origin']['step_name'] == 'first_step' }
    
    expect(user_log).to_not be_nil
    expect(user_log['origin']['operation']).to eq('LoggingOperation')
    expect(user_log['message']).to eq('First step executed')
    expect(user_log['payload']['detail']).to eq('some detail')
  end

  it 'allows changing the logger' do
    new_output = StringIO.new
    new_logger = Logger.new(new_output)
    new_logger.formatter = NextStation::Logging::Formatter::Json.new
    
    NextStation.configure do |config|
      config.logger = new_logger
    end

    LoggingOperation.new.call
    
    expect(new_output.string).to include('First step executed')
    expect(output.string).to_not include('First step executed')
  end

  describe 'Lifecycle events' do
    let(:events) { [] }

    before do
      NextStation.config.monitor.subscribe('operation.start') { |event| events << [:op_start, event] }
      NextStation.config.monitor.subscribe('operation.stop') { |event| events << [:op_stop, event] }
      NextStation.config.monitor.subscribe('step.start') { |event| events << [:step_start, event] }
      NextStation.config.monitor.subscribe('step.stop') { |event| events << [:step_stop, event] }
    end

    it 'broadcasts operation and step lifecycle events' do
      LoggingOperation.new.call({ input: 'test' }, { ctx: 'val' })

      expect(events.map(&:first)).to include(:op_start, :step_start, :step_stop, :op_stop)
      
      op_start = events.find { |e| e[0] == :op_start }[1]
      expect(op_start[:operation]).to eq('LoggingOperation')
      expect(op_start[:params]).to eq({ input: 'test' })
      expect(op_start[:context]).to eq({ ctx: 'val' })

      op_stop = events.find { |e| e[0] == :op_stop }[1]
      expect(op_stop[:operation]).to eq('LoggingOperation')
      expect(op_stop[:duration]).to be_a(Numeric)
      expect(op_stop[:result]).to be_success
      expect(op_stop[:state][:result]).to eq('success')

      step_starts = events.select { |e| e[0] == :step_start }.map { |e| e[1][:step] }
      expect(step_starts).to include(:first_step, :second_step)
    end
  end

  describe 'Retry events' do
    let(:events) { [] }

    before do
      NextStation.config.monitor.subscribe('step.retry') { |event| events << [:step_retry, event] }
    end

  class MonitorRetryOperation < NextStation::Operation
    process do
      step :flaky_step, attempts: 2, retry_if: ->(_state, _error) { true }
    end

    def flaky_step(state)
      if state.step_attempt == 1
        raise 'fail'
      else
        state[:result] = 'fixed'
        state
      end
    end
  end

  it 'broadcasts step.retry events' do
    MonitorRetryOperation.new.call
    
    expect(events.size).to eq(1)
    expect(events[0][0]).to eq(:step_retry)
    expect(events[0][1][:step]).to eq(:flaky_step)
    expect(events[0][1][:attempt]).to eq(1)
    expect(events[0][1][:error]).to be_a(RuntimeError)
  end
  end
end
