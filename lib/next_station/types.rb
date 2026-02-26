# frozen_string_literal: true

require 'dry-types'

module NextStation
  module Types
    include Dry.Types
    StrippedString = Types::String.constructor(&:strip)
    Email = Types::String.constructor { |v| v.strip.downcase }.constrained(format: /\A[^@\s]+@[^@\s]+\z/)
  end
end
