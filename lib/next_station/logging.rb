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
      Subscribers::Operation.subscribe(monitor)
      Subscribers::Step.subscribe(monitor)
      Subscribers::Custom.subscribe(monitor)
    end
  end
end
