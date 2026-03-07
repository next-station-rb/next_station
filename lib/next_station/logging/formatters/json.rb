# frozen_string_literal: true

require 'logger'
require 'json'

module NextStation
  module Logging
    module Formatter
      # A custom logger formatter that outputs log entries as JSON objects.
      #
      # This formatter is designed to work with the standard `Logger` class.
      # It structures log messages into a JSON format that includes severity, timestamp,
      # process ID, and structured data from the operation. It also automatically
      # includes OpenTelemetry trace and span IDs if the `opentelemetry-sdk` is present.
      class Json < Logger::Formatter
        # Avoid repeated defined? calls in a hot path
        OTEL_AVAILABLE = defined?(::OpenTelemetry::Trace)

        # Formats the log entry into a JSON string.
        #
        # @param severity [String] The log severity (e.g., 'INFO', 'WARN').
        # @param time [Time] The timestamp of the log event.
        # @param _progname [String] The program name (unused).
        # @param msg [String, Hash] The log message. If a Hash, it is treated as
        #   structured data with keys like `:message`, `:payload`, and `:operation`.
        #   If a String, it becomes the value of the `:message` key.
        # @return [String] The formatted log entry as a JSON string, terminated
        #   with a newline character.
        def call(severity, time, _progname, msg)
          data = msg.is_a?(Hash) ? msg : { message: msg.to_s }

          log_entry = {
            level: severity,
            time: time.utc.strftime('%Y-%m-%dT%H:%M:%S.%6N'),
            pid: Process.pid,
            origin: build_origin(data),
            message: data[:message],
            payload: data[:payload]
          }

          add_otel_context(log_entry) if OTEL_AVAILABLE

          # Compact the hash to remove nil values and ensure a newline
          JSON.generate(log_entry.compact) << "\n"
        end

        private

        # Constructs the origin hash, returning nil if no origin data is present.
        # This prevents an empty "origin": {} from appearing in the logs.
        def build_origin(data)
          origin = {}
          origin[:operation] = data[:operation] if data[:operation]
          origin[:event] = data[:event_kind] if data[:event_kind]
          origin[:step_name] = data[:step_name] if data[:step_name]
          origin[:step_attempt] = data[:step_attempt] if data[:step_attempt]

          origin.empty? ? nil : origin
        end

        # Adds OpenTelemetry trace and span IDs to the log entry if available.
        def add_otel_context(log_entry)
          context = ::OpenTelemetry::Trace.current_span.context
          if context.valid?
            log_entry[:trace_id] = context.hex_trace_id
            log_entry[:span_id] = context.hex_span_id
          end
        end
      end
    end
  end
end
