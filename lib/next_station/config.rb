# frozen_string_literal: true

require 'dry-configurable'
require 'dry-monitor'
require 'logger'
require_relative 'logging/formatters/json'

module NextStation
  extend Dry::Configurable

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

  # Apply the custom formatter to the default logger
  config.logger.formatter = Logging::Formatter::Json.new
end

require_relative 'logging'

# Automatically setup logging if enabled
NextStation::Logging.setup! if NextStation.config.logging_enabled
