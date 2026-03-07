# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Automatic Formatter Selection' do
  let(:logger) { Logger.new(File::NULL) }
  let(:environment) { NextStation::Environment.new }

  before do
    # Save original config
    @original_logger = NextStation.config.logger
    @original_environment = NextStation.config.environment
    
    # Setup test config
    NextStation.config.logger = logger
    NextStation.config.environment = environment
    
    # Clear ENV vars that might affect the environment detection
    %w[RAILS_ENV RACK_ENV APP_ENV RUBY_ENV].each { |var| ENV.delete(var) }
  end

  after do
    # Restore original config
    NextStation.config.logger = @original_logger
    NextStation.config.environment = @original_environment
  end

  it 'sets Console formatter when in development' do
    ENV['RAILS_ENV'] = 'development'
    
    # Trigger setup! which calls setup_formatter!
    NextStation::Logging.setup!
    
    expect(logger.formatter).to be_an_instance_of(NextStation::Logging::Formatter::Console)
  end

  it 'sets Json formatter when in production' do
    ENV['RAILS_ENV'] = 'production'
    
    NextStation::Logging.setup!
    
    expect(logger.formatter).to be_an_instance_of(NextStation::Logging::Formatter::Json)
  end

  it 'sets Json formatter by default (when not development)' do
    # No ENV set, but we can force it to something else that is not development
    ENV['RAILS_ENV'] = 'staging'
    
    NextStation::Logging.setup!
    
    expect(logger.formatter).to be_an_instance_of(NextStation::Logging::Formatter::Json)
  end
  
  it 'allows setting environment as a string' do
    NextStation.configure do |config|
      config.environment = 'production'
    end
    
    expect(NextStation.config.environment).to be_an_instance_of(NextStation::Environment)
    expect(NextStation.config.environment.current).to eq('production')
    expect(NextStation.config.environment.production?).to be true
    
    NextStation::Logging.setup!
    expect(logger.formatter).to be_an_instance_of(NextStation::Logging::Formatter::Json)
  end

  it 'allows setting environment as a string to development' do
    NextStation.configure do |config|
      config.environment = 'dev'
    end
    
    expect(NextStation.config.environment.current).to eq('dev')
    expect(NextStation.config.environment.development?).to be true
    
    NextStation::Logging.setup!
    expect(logger.formatter).to be_an_instance_of(NextStation::Logging::Formatter::Console)
  end
end
