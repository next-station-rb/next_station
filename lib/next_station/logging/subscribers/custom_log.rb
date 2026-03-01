# frozen_string_literal: true

NextStation.config.monitor.subscribe('log.custom') do |event|
  # Extract level and use the rest as the message hash
  event_data = event.to_h
  level = event_data.delete(:level) || :info
  event_data[:event_kind] = 'log.custom'
  event_data[:step_name] = event_data[:step_name]

  # We pass the whole hash. The Formatter will pick what it needs.
  NextStation.config.logger.send(level, event_data)
end

NextStation.config.monitor.subscribe('operation.start') do |event|
  # Extract level and use the rest as the message hash
  event_data = event.to_h
  level = event_data.delete(:level) || :info
  event_data[:message] = "Started operation: #{event_data[:operation]}"
  event_data[:event_kind] = 'operation.start'

  # We pass the whole hash. The Formatter will pick what it needs.
  NextStation.config.logger.send(level, event_data)
end

NextStation.config.monitor.subscribe('operation.stop') do |event|
  # Extract level and use the rest as the message hash
  event_data = event.to_h
  result = event_data[:result].success? ? 'success' : 'failure'
  level = event_data.delete(:level) || :info
  event_data[:message] = "completed operation: #{event_data[:operation]} with #{result}"
  event_data[:event_kind] = 'operation.stop'
  event_data[:payload] = {}
  event_data[:payload][:duration] = event_data[:duration]
  event_data[:payload][:result] = result

  # We pass the whole hash. The Formatter will pick what it needs.
  NextStation.config.logger.send(level, event_data)
end
