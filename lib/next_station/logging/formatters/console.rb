# frozen_string_literal: true

require 'logger'

module NextStation
  module Logging
    module Formatter
      class Console < Logger::Formatter
        # ANSI color codes
        SEVERITY_COLORS = {
          "DEBUG" => "\e[36m", # cyan
          "INFO"  => "\e[32m", # green
          "WARN"  => "\e[33m", # yellow
          "ERROR" => "\e[31m", # red
          "FATAL" => "\e[35m"  # magenta
        }.freeze

        OPERATION_COLOR = "\e[34m" # blue
        STEP_COLOR      = "\e[90m" # gray
        RESET_COLOR     = "\e[0m"

        def call(severity, datetime, _progname, msg)
          msg = msg.is_a?(Hash) ? msg : { message: msg.to_s }

          operation = msg[:operation]
          step_name = msg[:step_name] ? "/#{msg[:step_name]}" : ""
          payload   = msg[:payload] unless msg[:payload].to_h.empty?

          sev  = "#{SEVERITY_COLORS[severity]}#{severity[0]}#{RESET_COLOR}"
          op   = "#{OPERATION_COLOR}#{operation}#{RESET_COLOR}"
          step = step_name.empty? ? "" : "#{STEP_COLOR}#{step_name}#{RESET_COLOR}"

          "[#{sev}][#{datetime.strftime('%Y-%m-%d %H:%M:%S')}][#{op}#{step}] -- #{msg[:message]} #{payload}\n"
        end
      end
    end
  end
end
