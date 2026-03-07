# frozen_string_literal: true

require 'dry-configurable'
require 'dry-monitor'
require 'logger'
require_relative 'environment'
require_relative 'logging/formatters/json'
require_relative 'logging/formatters/console'

module NextStation
  extend Dry::Configurable

  # Define the environment
  setting :environment, default: Environment.new, constructor: ->(v) {
    if v.is_a?(String)
      env = Environment.new
      env.current = v
      env
    else
      v
    end
  }

  # Define the monitor
  setting :monitor, default: (
    monitor = Dry::Monitor::Notifications.new(:next_station)
    monitor.register_event('operation.start')
    monitor.register_event('operation.stop')
    monitor.register_event('step.start')
    monitor.register_event('step.stop')
    monitor.register_event('step.retry')
    monitor.register_event('log.custom')
    monitor
  )

  # Define the default logger (STDOUT)
  setting :logger, default: Logger.new($stdout)

  # Enable/disable default logging subscribers
  setting :logging_enabled, default: true

  # Default logging level (:info, :debug)
  setting :logging_level, default: :info
end

require_relative 'logging'

# Automatically setup logging if enabled
NextStation::Logging.setup! if NextStation.config.logging_enabled
