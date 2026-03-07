# frozen_string_literal: true

require 'spec_helper'
require 'next_station/environment'

RSpec.describe NextStation::Environment do
  subject(:environment) { described_class.new }

  before do
    # Clear relevant ENV variables to ensure a clean state for each test
    %w[RAILS_ENV RACK_ENV APP_ENV RUBY_ENV].each { |var| ENV.delete(var) }
  end

  describe '#current' do
    it "defaults to 'development' if no environment variable is set" do
      expect(environment.current).to eq('development')
    end

    it 'detects environment from RAILS_ENV' do
      ENV['RAILS_ENV'] = 'production'
      expect(environment.current).to eq('production')
    end

    it 'detects environment from RACK_ENV' do
      ENV['RACK_ENV'] = 'staging'
      expect(environment.current).to eq('staging')
    end

    it 'detects environment from APP_ENV' do
      ENV['APP_ENV'] = 'test'
      expect(environment.current).to eq('test')
    end

    it 'detects environment from RUBY_ENV' do
      ENV['RUBY_ENV'] = 'custom'
      expect(environment.current).to eq('custom')
    end

    it 'prioritizes based on the order in env_vars' do
      environment.env_vars = %w[CUSTOM_ENV RAILS_ENV]
      ENV['CUSTOM_ENV'] = 'custom'
      ENV['RAILS_ENV'] = 'production'
      
      expect(environment.current).to eq('custom')
    end
    
    it 'does not memoize the result' do
      ENV['RAILS_ENV'] = 'production'
      expect(environment.current).to eq('production')
      
      ENV['RAILS_ENV'] = 'development'
      expect(environment.current).to eq('development')
    end
  end

  describe '#current=' do
    it 'allows manually setting the environment name' do
      environment.current = 'staging'
      expect(environment.current).to eq('staging')
    end

    it 'overrides environment variables' do
      ENV['RAILS_ENV'] = 'production'
      environment.current = 'test'
      expect(environment.current).to eq('test')
    end
  end

  describe '#production?' do
    it 'returns true when environment is "production"' do
      ENV['RAILS_ENV'] = 'production'
      expect(environment.production?).to be true
    end

    it 'returns true when environment is "prod"' do
      ENV['RAILS_ENV'] = 'prod'
      expect(environment.production?).to be true
    end

    it 'returns true when environment is "prd"' do
      ENV['RAILS_ENV'] = 'prd'
      expect(environment.production?).to be true
    end

    it 'returns false when environment is "development"' do
      ENV['RAILS_ENV'] = 'development'
      expect(environment.production?).to be false
    end
    
    it 'respects custom production_names' do
      environment.production_names << 'staging'
      ENV['RAILS_ENV'] = 'staging'
      expect(environment.production?).to be true
    end
  end

  describe '#development?' do
    it 'returns true when environment is "development"' do
      ENV['RAILS_ENV'] = 'development'
      expect(environment.development?).to be true
    end

    it 'returns true when environment is "dev"' do
      ENV['RAILS_ENV'] = 'dev'
      expect(environment.development?).to be true
    end

    it 'returns false when environment is "production"' do
      ENV['RAILS_ENV'] = 'production'
      expect(environment.development?).to be false
    end
    
    it 'respects custom development_names' do
      environment.development_names << 'local'
      ENV['RAILS_ENV'] = 'local'
      expect(environment.development?).to be true
    end
  end
  
  describe 'configuration' do
    it 'allows configuring env_vars' do
      environment.env_vars = ['MY_APP_ENV']
      ENV['MY_APP_ENV'] = 'production'
      expect(environment.current).to eq('production')
    end
  end
end
