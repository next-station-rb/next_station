# frozen_string_literal: true

require_relative 'logging/subscribers/operation'
require_relative 'logging/subscribers/step'
require_relative 'logging/subscribers/custom'

module NextStation
  # Entry point for logging configuration and setup.
  module Logging
    # Initializes the default logging subscribers.
    # @param monitor [Dry::Monitor::Notifications] The monitor to subscribe to.
    # @return [void]
    def self.setup!(monitor = NextStation.config.monitor)
      setup_formatter!
      Subscribers::Operation.subscribe(monitor)
      Subscribers::Step.subscribe(monitor)
      Subscribers::Custom.subscribe(monitor)
    end

    # Selects the log formatter based on the current environment.
    # It uses the Console formatter for development and the JSON formatter otherwise.
    # @return [void]
    def self.setup_formatter!
      formatter = if NextStation.config.environment.development?
                    Formatter::Console.new
                  else
                    Formatter::Json.new
                  end
      NextStation.config.logger.formatter = formatter
    end

    private_class_method :setup_formatter!
  end
end

