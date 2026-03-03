# frozen_string_literal: true

require_relative 'next_station/config'

# NextStation is a lightweight, service-object like framework for Ruby
# that emphasizes structured operations, railway-oriented programming,
# and strong validation.
module NextStation

 # Base error class for all NextStation errors
  class Error < StandardError; end

  # Raised when a step method returns something other than a NextStation::State object.
  # This ensures that the Railway flow is maintained throughout the operation.
  class StepReturnValueError < Error; end

  # Raised when the operation finishes but the expected result key is missing from the state.
  class MissingResultKeyError < Error; end

  # Raised when the result does not match the defined schema.
  class ResultShapeError < Error; end

  # Raised when both a Dry::Struct class and a block are provided to result_schema.
  class DoubleResultSchemaError < Error; end

  # Raised when there is a configuration error related to validations.
  class ValidationError < Error; end
end

require_relative 'next_station/version'
require_relative 'next_station/types'
require_relative 'next_station/errors'
require_relative 'next_station/state'
require_relative 'next_station/result'
require_relative 'next_station/operation'
