# NextStation Plugin System Guide

NextStation's Plugin System allows you to extend the core functionality of operations without modifying the gem itself. This guide explains how the system works and how to design and implement your own plugins.

## Architecture Overview

A plugin in NextStation is a standard Ruby module. When you call `plugin :my_plugin` in an `Operation`, NextStation:
1. Loads the module registered as `:my_plugin`.
2. Extends the `Operation` class with methods from `MyPlugin::ClassMethods`.
3. Includes `MyPlugin::InstanceMethods` into the `Operation` instance.
4. Includes `MyPlugin::DSL` into `NextStation::Operation::Node`, making new methods available in the `process` block.
5. Extends the `NextStation::State` instance with `MyPlugin::State`.
6. Automatically registers errors defined in `MyPlugin::Errors`.
7. Calls `MyPlugin.configure(operation_class)` for any additional setup.
8. Registers lifecycle hooks if the plugin module responds to them.

## Designing a Plugin

### 1. Structure

Your plugin should follow this structure:

```ruby
module MyPlugin
  # Extends the Operation class
  module ClassMethods
    # We use the extended hook to add configuration via Dry::Configurable
    def self.extended(base)
      base.extend Dry::Configurable

      base.instance_eval do
        setting :my_plugin do
          setting :api_key
          setting :timeout, default: 30
        end
      end
    end
  end

  # Included in the Operation instance
  module InstanceMethods
    def my_instance_helper
      "Hello from instance"
    end

    # Example of an InstanceMethod that enriches data
    def enrich_user_data(state)
      user_id = state[:user_id]
      # Logic to fetch additional user data
      state[:user_full_name] = "John Doe" # Fetch from DB or external service
      state
    end

    # Example of an InstanceMethod that interacts with an external service
    def notify_external_system(state, payload)
      # Logic to send a notification to an external system
      # MyExternalService.send(payload)
      state
    end
    
    # Handler for DSL wrappers
    def run_my_wrapper(node, state)
      # Custom logic before
      result = execute_nodes(node.children, state)
      # Custom logic after
      result
    end
  end
  
  # Extended into the Node class (DSL in process block)
  module DSL
    def my_wrapper(&block)
      add_child(NextStation::Operation::Node.new(:wrapper, nil, { handler: :run_wrapper }, &block))
    end
  end

  # Mixed into the State instance during initialization
  module State
    def plugin_state_helper
      "useful data"
    end
  end
  
  # Automatically registers errors
  module Errors
    def self.definitions
      {
        my_plugin_error: {
          message: { en: "Something went wrong in the plugin" }
        }
      }
    end
  end

  # Lifecycle Hooks
  def self.on_operation_start(operation, state)
    # logic
  end

  def self.on_operation_stop(operation, result)
    # logic
  end

  def self.around_step(operation, node, state)
    # logic before
    result = yield
    # logic after
    result
  end

  # Configuration Hook
  def self.configure(operation_class)
    # Called when the plugin is loaded into a class
  end
end

# Register it
NextStation::Plugins.register(:my_plugin, MyPlugin)
```

### 2. Lifecycle Hooks

NextStation provides several hooks that your plugin can implement to intercept different stages of an operation's execution.

#### `on_operation_start(operation, state)`
Called once at the very beginning of the `call` method, before any steps are executed. Useful for initializing plugin-specific state or logging.

**Example: Performance Monitoring**
```ruby
def self.on_operation_start(operation, state)
  state[:_start_time] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end
```

#### `on_operation_stop(operation, result)`
Called once after the operation completes, whether it succeeded, failed, or was halted.

**Example: Log Operation Result**
```ruby
def self.on_operation_stop(operation, result)
  status = result.success? ? "SUCCESS" : "FAILURE"
  operation.publish_log(:info, "Operation #{operation.class.name} finished with status: #{status}")
end
```

#### `around_step(operation, node, state)`
Wraps the execution of every single step. **Important:** You must `yield` to allow the step (and other plugins) to execute. It receives the `node`, which contains the step `name` and `options`.

**Example: Step Execution Logging**
```ruby
def self.around_step(operation, node, state)
  operation.publish_log(:debug, "Starting step: #{node.name}")
  result = yield
  operation.publish_log(:debug, "Finished step: #{node.name}")
  result
end
```

#### `on_step_success(operation, node, state)`
Called after a step method returns successfully (and returns a `State` object).

**Example: Audit Trail**
```ruby
def self.on_step_success(operation, node, state)
  state[:audit_trail] ||= []
  state[:audit_trail] << { step: node.name, timestamp: Time.now }
end
```

#### `on_step_failure(operation, node, state, error)`
Called when a step raises an exception. This is called *before* the exception is re-raised or handled by retry logic.

**Example: Error Reporting**
```ruby
def self.on_step_failure(operation, node, state, error)
  # Sentry.capture_exception(error, extra: { step: node.name, state: state.to_h })
end
```

---

## Advanced Plugin Design

To create truly powerful plugins, you can leverage state extensions, custom errors, and configuration parameters.

### 1. Extending State
The `State` module in your plugin is mixed into every `NextStation::State` instance created for the operation. Use this to provide helper methods that simplify step logic.

```ruby
module MyPlugin
  module State
    def authenticated?
      context[:current_user].present?
    end

    def admin?
      authenticated? && context[:current_user].admin?
    end
  end
end
```
*Usage in a step:*
```ruby
def check_permission(state)
  error!(:unauthorized) unless state.admin?
  state
end
```

### 2. Custom Errors and Parameters
Plugins can register errors and even allow users to configure them.

```ruby
module MyPlugin
  module Errors
    def self.definitions
      {
        plugin_error: {
          message: { en: "Operation failed in %{plugin_name}: %{reason}" }
        }
      }
    end
  end
end
```
*Usage in a plugin's InstanceMethods:*
```ruby
module InstanceMethods
  def fail_with_reason(reason)
    error!(type: :plugin_error, msg_keys: { plugin_name: "MyPlugin", reason: reason })
  end
end
```

### 3. Instance Methods
The `InstanceMethods` module in your plugin is included in every `Operation` instance that uses the plugin. This is the place for shared logic that doesn't belong to a specific step, as well as for implementing **wrapper handlers**.

#### Helper Methods
You can define methods that simplify common tasks across different operations or steps. These methods have access to all the internals of the `Operation` class.

```ruby
module MyPlugin
  module InstanceMethods
    # An instance helper that can be called from any step
    def build_payload(state, user_id)
      { 
        user_id: user_id, 
        timestamp: Time.now.iso8601,
        source: self.class.name 
      }
    end

    # A helper to handle common error conditions
    def fail_gracefully!(reason)
      error!(type: :plugin_error, msg_keys: { reason: reason })
    end
  end
end
```
*Usage in a step:*
```ruby
def some_step(state)
  payload = build_payload(state, state[:user_id])
  # ExternalService.send(payload)
  state
rescue => e
  fail_gracefully!(e.message)
end
```

#### Wrapper Handlers
If your plugin provides a custom DSL (like a `transaction` block), the `InstanceMethods` module is where you implement the logic to handle that wrapper.

```ruby
module MyPlugin
  module InstanceMethods
    def run_my_wrapper(node, state)
      # 1. Access node options provided in the DSL
      timeout = node.options[:timeout] || 10
      
      # 2. Perform custom logic before executing inner steps
      # MyService.start_timer(timeout)
      
      # 3. Execute the children steps within this block
      result_state = execute_nodes(node.children, state)
      
      # 4. Perform custom logic after execution
      # MyService.stop_timer
      
      result_state
    end
  end
end
```

### 4. Plugin Configuration
The recommended way to handle plugin configuration is using `Dry::Configurable`. NextStation ensures that the `config` object is available for your plugin to extend.

Using `Dry::Configurable` provides a standardized, thread-safe way to define settings with defaults and nested namespaces.

```ruby
module MyPlugin
  module ClassMethods
    def self.extended(base)
      # Extend the operation class with configuration
      base.extend Dry::Configurable
      
      base.instance_eval do
        # It is highly recommended to namespace your plugin settings
        setting :my_plugin do
          setting :timeout, default: 30
          setting :retries, default: 3
        end
      end
    end
  end
end
```
*Usage in an Operation:*
```ruby
class MyOperation < NextStation::Operation
  plugin :my_plugin
  
  # Configure your plugin using the standardized DSL
  config.my_plugin.timeout = 60
end
```

While you can still use plain Ruby class methods and instance variables for configuration, `Dry::Configurable` is the preferred approach for consistency and robustness.

### 4. Designing instructions best practices:
When designing a plugin:
1. **Be Explicit**: Use clear naming conventions for hooks and methods.
2. **Document Options**: If your DSL methods take options, document them clearly in the `DSL` module.
3. **Use Namespace**: Prefix plugin-specific state keys (e.g., `state[:_my_plugin_data]`) to avoid collisions.
4. **Leverage Context**: Use `state.context` for read-only global data and `state` for mutable operation-specific data.

---

## Using Plugin Features (End-User Perspective)

When a plugin is loaded into an operation, its features are seamlessly integrated. Here is how a developer using your plugin will interact with its components.

### 1. Calling Instance Helpers from Steps

The methods defined in the plugin's `InstanceMethods` are directly available within your operation instance. You can call them from any step method.

```ruby
class RegisterUser < NextStation::Operation
  plugin :my_plugin # This plugin provides `build_payload` and `fail_gracefully!`

  process do
    step :process_user
  end

  def process_user(state)
    # 1. Using a helper method from the plugin
    payload = build_payload(state, state[:user_id])
    
    # ... logic to use the payload ...
    
    state
  rescue => e
    # 2. Using another helper to handle errors consistently
    fail_gracefully!(e.message)
  end
end
```

### 2. Using State Extensions

Methods from the plugin's `State` module are mixed into the `state` object. This makes your steps much more readable by moving complex logic into the state itself.

```ruby
class DeleteArticle < NextStation::Operation
  plugin :auth_plugin # This plugin provides `admin?` on the state object

  process do
    step :authorize
    step :delete
  end

  def authorize(state)
    # The `admin?` method is provided by the auth_plugin's State module
    unless state.admin?
      error!(:unauthorized)
    end
    state
  end

  def delete(state)
    # ... delete logic ...
    state
  end
end
```

### 3. Using DSL Wrappers in the Process Block

DSL methods provided by the plugin's `DSL` module allow you to wrap steps or groups of steps, providing powerful flow control or automatic behavior (like transactions or logging).

```ruby
class UpdateOrder < NextStation::Operation
  plugin :transactional # This plugin provides the `transaction` block

  process do
    step :validate
    
    # Everything inside this block is wrapped in a DB transaction
    transaction do
      step :update_stock
      step :capture_payment
    end
    
    step :notify_user
  end
end
```

### 4. Configuring the Plugin

As an end-user, you configure the plugin at the class level using the `config` object. These settings are then used by the plugin's internal logic.

```ruby
class ImportData < NextStation::Operation
  plugin :api_client_plugin
  
  # Configure plugin-specific settings
  config.api_client.timeout = 60
  config.api_client.retries = 5

  process do
    step :fetch_remote_data
  end
end
```

---

## Example: ActiveRecord Transaction Plugin

This plugin wraps a group of steps in a database transaction.

```ruby
module NextStation
  module Plugins
    module Transactional
      module DSL
        def transaction(&block)
          add_child(
            NextStation::Operation::Node.new(
              :wrapper, 
              nil, 
              { handler: :run_transaction }, 
              &block
            )
          )
        end
      end
      
      module InstanceMethods
        def run_transaction(node, state)
          ActiveRecord::Base.transaction do
            execute_nodes(node.children, state)
          end
        rescue ActiveRecord::Rollback
          # The operation flow will stop because steps inside 
          # are executed within execute_nodes.
          state
        end
      end
      
      module State
        def in_transaction?
          # You could implement logic to check transaction depth
          true 
        end
      end
      
      module Errors
        def self.definitions
          {
            transaction_error: {
              message: { en: "Transaction failed: %{message}" }
            }
          }
        end
      end
    end
    
    register(:transactional, Transactional)
  end
end
```

### Usage:

```ruby
class CreateUser < NextStation::Operation
  plugin :transactional

  process do
    step :validate
    transaction do
      step :create_user
      step :create_profile
    end
    step :send_welcome_email
  end
  
  # ... step definitions ...
end
```

## Tips for Plugin Developers

1.  **Thread Safety**: Ensure your plugin does not use mutable global state.
2.  **Inheritance**: NextStation handles plugin inheritance. If a parent class uses a plugin, the subclass will also have it.
3.  **Namespace**: Use a unique namespace for your plugin methods to avoid collisions with other plugins or core NextStation methods.
4.  **Error Handling**: Use the `Errors` module to register custom errors. This allows users to customize the messages in their operations.
5.  **State Extension**: Be careful when extending `State`. Only add methods that are genuinely useful for steps across many operations.
