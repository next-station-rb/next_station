module NextStation
  # Base error class for all NextStation errors
  class Error < StandardError; end

  # Raised when a step method returns something other than a NextStation::State object.
  # This ensures that the Railway flow is maintained throughout the operation.
  class StepReturnValueError < Error; end

  # Raised when the operation finishes but the expected result key is missing from the state.
  class MissingResultKeyError < Error; end
end

require_relative "next_station/version"
require_relative "next_station/state"
require_relative "next_station/result"
require_relative "next_station/operation"
