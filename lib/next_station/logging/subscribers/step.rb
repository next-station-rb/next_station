# frozen_string_literal: true

require_relative 'base'

module NextStation
  module Logging
    module Subscribers
      # Subscriber for step lifecycle events.
      # @api private
      class Step < Base
        # @param monitor [Dry::Monitor::Notifications]
        def subscribe(monitor)
          monitor.subscribe('step.start') { |event| on_start(event) }
          monitor.subscribe('step.stop') { |event| on_stop(event) }
          monitor.subscribe('step.retry') { |event| on_retry(event) }
        end

        # @param event [Dry::Monitor::Event]
        def on_start(event)
          log_event(event, level: :debug, extra_data: {
            message: "Started step: #{event[:step]} in #{event[:operation]}",
            event_kind: 'step.start',
            step_name: event[:step],
            operation: event[:operation]
          })
        end

        # @param event [Dry::Monitor::Event]
        def on_stop(event)
          log_event(event, level: :debug, extra_data: {
            message: "Completed step: #{event[:step]} in #{event[:operation]}",
            event_kind: 'step.stop',
            step_name: event[:step],
            operation: event[:operation],
            payload: {
              duration: event[:duration]
            }
          })
        end

        # @param event [Dry::Monitor::Event]
        def on_retry(event)
          log_event(event, level: :warn, extra_data: {
            message: "Retrying step: #{event[:step]} (attempt #{event[:attempt]})",
            event_kind: 'step.retry',
            step_name: event[:step],
            operation: event[:operation],
            step_attempt: event[:attempt]
          })
        end
      end
    end
  end
end
