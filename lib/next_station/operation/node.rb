# frozen_string_literal: true

module NextStation
  class Operation
    # Represents a node in the operation's execution graph (step or branch).
    class Node
      # @return [Symbol] The node type (:step, :branch, or :root).
      attr_reader :type
      # @return [Symbol, nil] The name of the step.
      attr_reader :name
      # @return [Hash] Execution options.
      attr_reader :options
      # @return [Array<Node>] Child nodes (for branches or root).
      attr_reader :children

      # @param type [Symbol] :step, :branch, or :root.
      # @param name [Symbol, nil] The name of the step.
      # @param options [Hash] Execution options.
      # @yield The block for branch nodes.
      def initialize(type, name = nil, options = {}, &block)
        @type = type
        @name = name
        @options = options
        @children = []
        instance_eval(&block) if block_given?
      end

      # Adds a step to the node.
      # @param name [Symbol] The method name to execute.
      # @param options [Hash] Execution options like :skip_if, :retry_if, :attempts, :delay.
      def step(name, options = {})
        @children << Node.new(:step, name, options)
      end

      # Adds a branch to the node.
      # @param condition [Proc] A proc that receives the state and returns a boolean.
      # @yield The block defining steps inside the branch.
      def branch(condition, &block)
        @children << Node.new(:branch, nil, { condition: condition }, &block)
      end
    end
  end
end
