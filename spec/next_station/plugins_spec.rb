# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Plugin System' do
  let(:dummy_plugin) do
    mod = Module.new do
      def self.on_operation_start(_operation, _state)
        @start_called = true
      end

      def self.on_operation_stop(_operation, _result)
        @stop_called = true
      end

      def self.around_step(_operation, _node, state)
        state[:around_called_before] = true
        result = yield
        state[:around_called_after] = true
        result
      end

      def self.on_step_success(_operation, _node, state)
        state[:success_hook_called] = true
      end

      def self.on_step_failure(_operation, _node, _state, _error)
        @failure_hook_called = true
      end

      def self.start_called?
        @start_called
      end

      def self.stop_called?
        @stop_called
      end

      def self.failure_hook_called?
        @failure_hook_called
      end

      def self.reset!
        @start_called = false
        @stop_called = false
        @failure_hook_called = false
      end
    end

    mod.const_set(:ClassMethods, Module.new do
      def plugin_config
        @plugin_config ||= { enabled: true }
      end
    end)

    mod.const_set(:InstanceMethods, Module.new do
      def run_wrapper(node, state)
        state[:wrapper_called] = true
        execute_nodes(node.children, state)
      end
    end)

    mod.const_set(:DSL, Module.new do
      def my_wrapper(&block)
        add_child(NextStation::Operation::Node.new(:wrapper, nil, { handler: :run_wrapper }, &block))
      end
    end)

    mod.const_set(:State, Module.new do
      def plugin_helper
        'helper_called'
      end
    end)

    mod.const_set(:Errors, Module.new do
      def self.definitions
        {
          plugin_error: {
            message: { en: "Plugin error: %{msg}" }
          }
        }
      end
    end)

    mod
  end

  before do
    NextStation::Plugins.register(:dummy, dummy_plugin)
    dummy_plugin.reset!
  end

  let(:operation_class) do
    Class.new(NextStation::Operation) do
      plugin :dummy

      process do
        my_wrapper do
          step :work
        end
      end

      def work(state)
        state[:work_done] = true
        state[:helper_result] = state.plugin_helper
        state[:result] = 'success'
        state
      end
    end
  end

  it 'extends the operation with class methods' do
    expect(operation_class.plugin_config).to eq({ enabled: true })
  end

  it 'extends the state with state methods' do
    result = operation_class.call
    expect(result.value).to eq('success')
    # Since we can't easily access the internal state of the result directly for all keys 
    # (only via result.value if it's the result key), we rely on hooks or other side effects if needed.
    # But wait, our dummy plugin's work step sets keys in the state.
  end

  it 'triggers lifecycle hooks and DSL wrappers' do
    result = operation_class.call
    expect(result.success?).to be true
    
    expect(dummy_plugin.start_called?).to be true
    expect(dummy_plugin.stop_called?).to be true
  end

  it 'registers plugin errors' do
    expect(operation_class.error_definitions).to have_key(:plugin_error)
  end

  it 'supports inheritance of plugins' do
    subclass = Class.new(operation_class)
    expect(subclass.loaded_plugins).to include(dummy_plugin)
    expect(subclass.error_definitions).to have_key(:plugin_error)
  end

  it 'handles step failures with hooks' do
    fail_op = Class.new(NextStation::Operation) do
      plugin :dummy
      process { step :fail_step }
      def fail_step(_state); raise 'boom'; end
    end

    fail_op.call
    expect(dummy_plugin.failure_hook_called?).to be true
  end

  it 'supports Dry::Configurable for plugin configuration' do
    config_plugin = Module.new
    config_plugin.const_set(:ClassMethods, Module.new do
      def self.extended(base)
        base.extend Dry::Configurable
        base.instance_eval do
          setting :test_plugin do
            setting :api_key, default: 'secret'
          end
        end
      end
    end)
    NextStation::Plugins.register(:config_plugin, config_plugin)

    op_class = Class.new(NextStation::Operation) do
      plugin :config_plugin
      config.test_plugin.api_key = 'changed'
      process { step :check_config }
      def check_config(state)
        state[:config_val] = self.class.config.test_plugin.api_key
        state[:result] = state[:config_val]
        state
      end
    end

    result = op_class.call
    expect(result.value).to eq('changed')
  end
end
