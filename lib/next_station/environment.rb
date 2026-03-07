# frozen_string_literal: true

module NextStation
  # Detects the current environment (e.g., development, production)
  # based on a configurable set of environment variables.
  class Environment
    attr_accessor :env_vars, :production_names, :development_names

    def initialize
      # A list of common environment variables to check for the environment name.
      @env_vars = %w[RAILS_ENV RACK_ENV APP_ENV RUBY_ENV]
      
      # Names that are considered to be a "production" environment.
      @production_names = %w[production prod prd]
      
      # Names that are considered to be a "development" environment.
      @development_names = %w[development dev]
    end

    # Returns the current environment name. Defaults to 'development' if none is found.
    # @return [String]
    def current
      @current ||= env_vars.map { |var| ENV[var] }.compact.first || 'development'
    end

    # Checks if the current environment is production.
    # @return [Boolean]
    def production?
      production_names.include?(current)
    end

    # Checks if the current environment is development.
    # @return [Boolean]
    def development?
      development_names.include?(current)
    end
  end
end
