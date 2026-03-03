# frozen_string_literal: true

require_relative 'base'

module NextStation
  module Logging
    module Subscribers
      # Subscriber for operation lifecycle events.
      # @api private
      class Operation < Base
        # @param monitor [Dry::Monitor::Notifications]
        def subscribe(monitor)
          monitor.subscribe('operation.start') { |event| on_start(event) }
          monitor.subscribe('operation.stop') { |event| on_stop(event) }
        end

        # @param event [Dry::Monitor::Event]
        def on_start(event)
          log_event(event, extra_data: {
            message: "Started operation: #{event[:operation]}",
            event_kind: 'operation.start'
          })
        end

        # @param event [Dry::Monitor::Event]
        def on_stop(event)
          result_status = event[:result].success? ? 'success' : 'failure'
          
          log_event(event, extra_data: {
            message: "completed operation: #{event[:operation]} with #{result_status}",
            event_kind: 'operation.stop',
            payload: {
              duration: event[:duration],
              result: result_status
            }
          })
        end
      end
    end
  end
end
