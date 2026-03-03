# frozen_string_literal: true

require_relative 'base'

module NextStation
  module Logging
    module Subscribers
      # Subscriber for custom log events manually triggered.
      # @api private
      class Custom < Base
        # @param monitor [Dry::Monitor::Notifications]
        def subscribe(monitor)
          monitor.subscribe('log.custom') { |event| on_custom(event) }
        end

        # @param event [Dry::Monitor::Event]
        def on_custom(event)
          log_event(event, extra_data: {
            event_kind: 'log.custom'
          })
        end
      end
    end
  end
end
