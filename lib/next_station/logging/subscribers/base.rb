# frozen_string_literal: true

module NextStation
  module Logging
    module Subscribers
      # @api private
      class Base
        # Map levels to their numeric priority for comparison.
        LEVELS = {
          debug: 0,
          info: 1,
          warn: 2,
          error: 3,
          fatal: 4,
          unknown: 5
        }.freeze

        # Subscribes a new instance to the monitor.
        # @param monitor [Dry::Monitor::Notifications]
        def self.subscribe(monitor)
          new.subscribe(monitor)
        end

        # Subscribes to the event(s) in the monitor.
        # @param monitor [Dry::Monitor::Notifications]
        def subscribe(monitor)
          raise NotImplementedError
        end

        protected

        # Default log level if none is provided in the event.
        # @return [Symbol]
        def default_level
          :info
        end

        # Logs the event data to the configured logger.
        # @param event [Dry::Monitor::Event]
        # @param level [Symbol, nil] Explicit level, or derived from event/default.
        # @param extra_data [Hash] Additional data to merge into the log entry.
        def log_event(event, level: nil, extra_data: {})
          # Add this check to respect `config.logging_enabled = false`
          return unless NextStation.config.logging_enabled

          event_data = event.to_h
          log_level = level || event_data.delete(:level) || default_level

          # Filter by logging_level
          return unless level_sufficient?(log_level)

          # Merge data while preserving the original event data
          payload = event_data.merge(extra_data)

          # We pass the whole hash. The Formatter will pick what it needs.
          NextStation.config.logger.send(log_level, payload)
        end

        private

        # @param log_level [Symbol] The level of the current log event.
        # @return [Boolean] True if the log level is equal or higher than configured.
        def level_sufficient?(log_level)
          configured_level = NextStation.config.logging_level
          LEVELS.fetch(log_level, 1) >= LEVELS.fetch(configured_level, 1)
        end
      end
    end
  end
end
