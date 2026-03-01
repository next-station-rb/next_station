# frozen_string_literal: true

# Load all logging subscribers.
Dir[File.join(__dir__, 'logging/subscribers', '*.rb')].sort.each { |file| require file }
