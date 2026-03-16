# frozen_string_literal: true

module NextStation
  # Central registry for NextStation plugins.
  module Plugins
    @registry = {}

    # Registers a plugin.
    # @param name [Symbol] The plugin name.
    # @param mod [Module] The plugin module.
    def self.register(name, mod)
      @registry[name] = mod
    end

    # Loads a plugin by name.
    # @param name [Symbol]
    # @return [Module]
    # @raise [KeyError] If the plugin is not registered.
    def self.load_plugin(name)
      @registry.fetch(name)
    end
  end
end
