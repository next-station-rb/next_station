# NextStation

NextStation is a lightweight, flexible framework for building service objects (Operations) in Ruby. It provides a clean DSL to define business processes, manage state, and handle flow control.

## Index

- [Installation](#installation)
- [Getting Started](#getting-started)
- [Core Concepts](#core-concepts)
- [Flow Control](#flow-control)
- [Railway Pattern & Errors](#railway-pattern--errors)
- [Input Validation (dry-validation)](#input-validation-dry-validation)
- [Logging and Monitoring](#logging-and-monitoring)
- [Dependency Injection](#dependency-injection)
- [Nested Operations (Operation Composition)](#nested-operations-operation-composition)
- [Advanced Usage](#advanced-usage)
- [License](#license)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'next_station'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install next_station

## Getting Started

Define an operation by inheriting from `NextStation::Operation` and using the `process` block. You can use `result_at` to specify which key from the state should be returned as the result value:

```ruby
class CreateUser < NextStation::Operation
  result_at :user_id

  process do
    step :validate_params
    step :persist_user
    step :send_welcome_email
  end

  def validate_params(state)
    raise "Invalid email" unless state.params[:email].include?("@")
    state
  end

  def persist_user(state)
    # state[:params] contains the initial input
    user = User.create(state.params)
    state[:user_id] = user.id
    state
  end

  def send_welcome_email(state)
    # Logic to send email
    state
  end
end

# Usage
result = CreateUser.new.call(email: "user@example.com", name: "John Doe")

if result.success?
  puts "User created with ID: #{result.value}"
else
  puts "Error: #{result.error.message}"
end
```

## Core Concepts

### State

Every operation execution revolves around a `State` object. It holds:

- **params**: The initial input passed to `.call(params, context)`.
- **context**: Read-only configuration or dependencies (e.g., current_user, repository).
- **data**: A hash-like storage where steps can read and write data. By default, it contains a reference to `params` under the `:params` key.

Steps always receive the `state` as their only argument and MUST return it. If a step returns something else (or `nil`), a `NextStation::StepReturnValueError` will be raised.

Inside a step, you can access params in two ways:
```ruby
state.params[:email]  # Recommended
state[:params][:email] # Also valid
```

Direct access to params via top-level state keys (e.g., `state[:email]`) is NOT supported to avoid confusion between initial input and operation data.

### Result

Operations return a `NextStation::Result` object (either a `Success` or `Failure`) which provides:

- `success?`: Boolean indicating if the operation finished successfully.
- `failure?`: Boolean indicating if the operation failed or was halted.
- `value`: The data returned by the operation (for `Success`).
- `error`: A `Result::Error` object containing `type`, `message`, `help_url`, and `details`.

## Flow Control

NextStation provides powerful tools to manage complex business logic.

### Step Skips

You can skip a step conditionally using `skip_if`:

```ruby
step :send_notification, skip_if: ->(state) { state.params[:do_not_contact] }
```

### Branching

Use `branch` to execute a group of steps only when a condition is met:

```ruby
branch ->(state) { state.params[:is_admin] } do
  step :grant_admin_privileges
  step :log_admin_action
end
```

Branches can be nested for complex flows.

### Resilience (Retry Logic)

Add resilience to flaky steps using `retry_if`, `attempts`, and `delay`:

```ruby
process do
  step :call_external_api,
       retry_if: ->(state, exception) { exception.is_a?(Timeout::Error) },
       attempts: 3,
       delay: 1
end
```

The `retry_if` lambda receives both the current `state` and the `exception` (if any). It should return `true` if the step should be retried.

You can also retry based on the state result even if no exception was raised:

```ruby
step :check_job_status,
     retry_if: ->(state, _exception) { state[:job_status] == "pending" },
     attempts: 5,
     delay: 2
```

Inside a step, you can check the current attempt number using `state.step_attempt`:

```ruby
def call_external_api(state)
  puts "Executing attempt number: #{state.step_attempt}"
  # ...
  state
end
```

## Railway Pattern & Errors

NextStation supports the Railway pattern, allowing you to explicitly handle success and failure paths using a structured error DSL.

### Defining Errors

Use the `errors` block to define possible error types:

```ruby
class CreateUser < NextStation::Operation
  errors do
    error_type :email_taken do
      message en: "Email %{email} is taken"
      message sp: "El correo %{email} ya existe"
      help_url "http://example.com/support/email-taken"
    end
  end
end
```

### External Errors

You can also pass an existing `NextStation::Errors` class to `errors`.

```ruby

class MyExternalErrors < NextStation::Errors
  error_type :invalid_token do
    message en: "Invalid token"
    message sp: "Token inválido"
  end
end

class GetUser < NextStation::Operation
  errors MyExternalErrors
  # ...
end
```

### Shared Errors

You can define shared error collections by inheriting from `NextStation::Errors`. This allows you to reuse common error
definitions across multiple operations.

```ruby

class MySharedErrors < NextStation::Errors
  error_type :not_found do
    message en: "Resource not found", sp: "Recurso no encontrado"
  end

  error_type :unauthorized do
    message en: "You are not authorized to perform this action"
  end
end

class GetUser < NextStation::Operation
  # Pass the class directly to errors
  errors MySharedErrors

  # You can still add operation-specific errors or override shared ones
  errors do
    error_type :user_inactive do
      message en: "User is inactive"
    end

    error_type :not_found do
      message en: "User with ID %{id} not found"
    end
  end
end
```

### Halting Execution

Use `error!` within a step to stop the operation immediately and return a failure result:

```ruby
def check_email(state)
  if User.exists?(state.params[:email])
    error!(
      type: :email_taken, 
      msg_keys: { email: state.params[:email] }, 
      details: { timestamp: Time.now }
    )
  end
  state
end
```

### Multi-language Support

You can specify the desired language when calling the operation via the context:

```ruby
result = CreateUser.new.call({ email: "taken@example.com" }, { lang: :sp })
result.error.message # => "El correo taken@example.com ya existe"
```

If the requested language is not defined, it defaults to `:en`.

## Input Validation (dry-validation)

NextStation integrates with `dry-validation` to provide powerful input guarding and coercion.

### Defining a Contract

Use `validate_with` to define your validation rules. You can use a block to define the contract inline, or pass an
existing contract class.

#### Inline Contract

```ruby
class CreateUser < NextStation::Operation
  # Define the contract inline
  validate_with do
    params do
      required(:email).filled(:string, format?: /@/)
      required(:age).filled(:integer, gteq?: 18)
    end
  end

  process do
    step :validation # Explicitly run the validation
    step :persist
  end

  def persist(state)
    # state.params now contains COERCED values (e.g., age is an Integer)
    User.create!(state.params)
    state
  end
end
```

#### External Contract

You can also pass an existing `Dry::Validation::Contract` class.

```ruby

class MyExternalContract < Dry::Validation::Contract
  params do
    required(:token).filled(:string)
  end
end

class Authenticate < NextStation::Operation
  validate_with MyExternalContract

  process do
    step :validation
    step :authorize
  end

  def authorize(state)
    # state.params[:token] is available here
    state
  end
end
```

### The :validation Step

Validation is NOT automatic. You must explicitly add `step :validation` in your `process` block.

- **Failure**: If validation fails, the operation halts immediately and returns a `Result::Failure` with type
  `:validation`.
- **Details**: `result.error.details` contains the raw error hash from `dry-validation`.
- **Coercion**: On success, `state.params` is updated with the coerced and filtered values from the validation result.

### Customizing Validation Errors

You can override the default validation error message using the `errors` DSL:

```ruby

class UpdateProfile < NextStation::Operation
  errors do
    error_type :validation do
      message en: "The provided data is invalid: %{errors}",
              sp: "Los datos son inválidos: %{errors}"
    end
  end

  validate_with do
    # ...
  end
  process { step :validation }
end
```

If no custom message is defined, NextStation uses a default message: "One or more parameters are invalid. See validation
details." (available in English and Spanish).

### Localization

NextStation automatically handles localization for validation errors. It defaults to a "slim" approach using the `:yaml` backend, loading translations from its internal configuration.
For this gem, the locale yml file is located at `lib/next_station/config/errors.yml`.

The `lang` passed in the context (e.g., `call(params, { lang: :sp })`) is automatically respected.

```ruby
class UpdateProfile < NextStation::Operation
  validate_with do
    params do
      required(:name).filled(:string)
    end
  end

  process { step :validation }
end

# Pass the desired language in the context
result = UpdateProfile.new.call({ name: "" }, { lang: :sp })

# result.error.details will contain the localized messages from dry-validation
# => { name: ["debe estar lleno"] }
```

### Validation Enforcement

By default, if you define `validate_with`, the validation is considered enabled.

- **force_validation!**: Ensures that `step :validation` is present in the `process` block. If missing, calling the
  operation will raise a `NextStation::ValidationError`.
- **skip_validation!**: Disables the validation check even if `step :validation` is present.

## Logging and Monitoring

NextStation provides a built-in event system powered by `dry-monitor` to track operation lifecycle and user-defined
logs.

### Bult-in Logging

Inside your operation steps, you can use `publish_log` to broadcast custom events. These are automatically routed to the
configured logger by default.

```ruby

class CreateUser < NextStation::Operation
  def persist(state)
    # ... logic ...
    publish_log(:info, "User persisted successfully", user_id: state[:user_id])
    state
  end
end
```

The log will be structured as:

```JSON
{
  "level": "INFO",
  "time": "2026-03-01T20:32:54.123456",
  "pid": 92323,
  "origin": {
    "operation": "CreateUser",
    "event": "log.custom",
    "step_name": "persist"
  },
  "message": "Hello World from 1st step",
  "payload": {
    "user_id": 1
  }
}
```

- The log will automatically include the fields `trace_id` and `span_id` if the OpenTelemetry SDK is detected,

### Configuration

NextStation features an environment-aware logging configuration that works out of the box.

- **In Development:** It defaults to the `Console` formatter, providing human-readable, colorized output to `STDOUT`.
  Example: `[I][2026-03-01 20:32:54][CreateUser/persist] -- User persisted successfully {:user_id=>1}`
- **In Production (or any other environment):** It defaults to the `Json` formatter, which is ideal for structured logging.

You can customize the logger, logging level, and other options:

```ruby
NextStation.configure do |config|
  # Use a different logger (e.g., Rails.logger)
  config.logger = Rails.logger
  
  # Manually override the formatter if needed
  # config.logger.formatter = NextStation::Logging::Formatter::Json.new

  # Set logging level (:debug, :info, :warn, :error, :fatal, :unknown).
  # :info (default): logs everything except debug level.
  # :warn: logs warn and above levels.
  # :debug: logs everything including individual step start/stop events.
  config.logging_level = :info
  
  # To disable default logging subscribers:
  # config.logging_enabled = false
  # config.monitor = MyCustomMonitor.new
end
```

### Lifecycle Events

NextStation automatically broadcasts events for every operation and step execution. You can subscribe to these events to
integrate with external monitoring tools (Datadog, Prometheus, etc.):

```ruby
NextStation.config.monitor.subscribe("operation.stop") do |event|
  puts "Operation #{event[:operation]} finished in #{event[:duration]}ms"
end

NextStation.config.monitor.subscribe("step.retry") do |event|
  puts "Step #{event[:step]} failed (attempt #{event[:attempt]}) with: #{event[:error].message}"
end
```

**Available Events:**

- `operation.start`: Triggered when an operation starts.
- `operation.stop`: Triggered when an operation finishes (success or failure). Includes `duration` and `result`.
- `step.start`: Triggered before a step starts.
- `step.stop`: Triggered after a step finishes. Includes `duration` and `state`.
- `step.retry`: Triggered when a step fails and is about to be retried.

## Dependency Injection

NextStation includes a lightweight Dependency Injection (DI) system to help you decouple your operations from their external dependencies.

### Declaring Dependencies

Use the `depends` method to declare dependencies and their defaults. Defaults can be static values or lazy lambdas:

```ruby
class CreateUser < NextStation::Operation
  depends mailer: -> { Mailer.new },
          repository: UserRepository.new

  process do
    step :send_welcome_email
  end

  def send_welcome_email(state)
    # Access dependencies using the dependency() method
    dependency(:mailer).send_welcome(state.params[:email])
    state
  end
end
```

### Injecting Dependencies

You can override the default dependencies when instantiating the operation by passing the `deps:` keyword argument:

```ruby
# In your tests
mock_mailer = double("Mailer")
operation = CreateUser.new(deps: { mailer: mock_mailer })
operation.call(email: "test@example.com")
```

### Inheritance

Dependencies are inherited and can be overridden in subclasses:

```ruby
class BaseOp < NextStation::Operation
  depends logger: Logger.new
end

class MyOp < BaseOp
  depends logger: CustomLogger.new # Overrides parent dependency
end
```

## Nested Operations (Operation Composition)

Operations can invoke other operations using the `call_operation` helper. This maintains the Railway pattern, shares context (e.g., `current_user`, `lang`), and handles error propagation automatically.

```ruby
class SyncUser < NextStation::Operation
  depends remote_op: -> { RemoteOp.new }

  errors do
    error_type :provider_error do
      message en: "External Sync Failed: %{reason}"
    end
  end

  process do
    step :fetch_remote_data
    step :other_step
  end

  def fetch_remote_data(state)
    # 1. Automatically shares context (state.context)
    # 2. Dynamic params via Proc (or pass a Hash directly)
    # 3. Results stored in state[:remote_profile]
    # 4. If RemoteOp fails with :provider_error, this step halts and 
    #    the parent returns its own template for :provider_error.
    call_operation(
      state, 
      dependency(:remote_op), 
      with_params: ->(s) { { uid: s.params[:id] } },
      store_result_in_key: :remote_profile
    )
  end

  def other_step(state)
    state[:remote_profile] # Access the result from the child operation
    state
  end
end
```

### Error Propagation Rules

- **Mapped Error**: If the Parent Operation has a matching `error_type` defined, it "intercepts" the failure. The resulting error uses the Parent's message template but is populated with the Child's `msg_keys` and `details`.
- **Transparent Error**: If the Parent has NOT defined that error type, the child's `Error` object is propagated exactly as is (including its already resolved message).

The `call_operation` helper triggers the internal Halt mechanism, allowing parent step controls like `retry_if` to function as expected.

## Advanced Usage

### Result Value and `result_at`

Operations return a value encapsulated in the `Result::Success` object. You have two ways to define what this value is:

#### 1. Default Result Key (`:result`)
If you don't specify anything, NextStation looks for the `:result` key in the state.

```ruby
class MyOperation < NextStation::Operation
  process do
    step :do_work
  end

  def do_work(state)
    state[:result] = { message: "All good!" }
    state
  end
end

result = MyOperation.new.call
result.value # => { message: "All good!" }
```

#### 2. Customizing with `result_at`
If you want to use a more descriptive key for your result, use `result_at`.

```ruby
class MyOperation < NextStation::Operation
  result_at :user_record

  process do
    step :find_user
  end

  def find_user(state)
    state[:user_record] = User.find(state.params[:id])
    state
  end
end

result = MyOperation.new.call
result.value # => <User instance>
```

> **Note:** If the expected key (either `:result` or the one defined by `result_at`) is missing from the state at the end of the operation, a `NextStation::Error` will be raised. This ensures that you explicitly define the output of your operations.

### Output Shapes (dry-struct)

You can enforce the structure of the success result using the `result_schema` DSL, which leverages the `dry-struct` gem.

```ruby
class CreateUser < NextStation::Operation
  result_at :user_data

  result_schema do
    attribute :id, NextStation::Types::Integer
    attribute :email, NextStation::Types::String
    attribute :address do
      attribute :city,   NextStation::Types::String
      attribute :street, NextStation::Types::String
    end
    attribute :metadata, NextStation::Types::Any
  end

  process do
    step :set_data
  end

  def set_data(state)
    state[:user_data] = {
      id: 1,
      email: "john@example.com",
      address: { city: "NYC", street: "Main St" },
      metadata: { foo: "bar" }
    }
    state
  end
end
```

#### Lazy Validation

The result schema is applied **lazily**. Validation and coercion only occur when you call `result.value`.

```ruby
op = CreateUser.new.call(params)
op.success? # => true (Operation finished without errors)

# Validation happens now:
op.value 
# => #<CreateUser::ResultSchema id=1 email="john@example.com" ...>

# If the data doesn't match the schema:
# => raises NextStation::ResultShapeError
```

#### External Schemas

You can also pass an existing `Dry::Struct` class to `result_schema`. This is useful for sharing schemas across multiple operations.

```ruby
class MySharedSchema < Dry::Struct
  attribute :id, NextStation::Types::Integer
end

class CreateUser < NextStation::Operation
  result_schema MySharedSchema
end
```

Note that `result_schema` accepts either a `Dry::Struct` class OR a block, but not both. Providing both will raise a `NextStation::DoubleSchemaError`.

#### Enabling/Disabling Enforcement

By default, enforcement is enabled if a `result_schema` is defined. You can explicitly control this behavior:

```ruby
class CreateUser < NextStation::Operation
  result_schema do
    # ...
  end

  # Force enforcement (default if schema is present)
  enforce_result_schema 

  # Disable enforcement (result.value will return the raw hash)
  disable_result_schema
end
```

> **Note:** If `enforce_result_schema` is enabled but no `result_schema` is defined (either in the class or its ancestors), calling `result.value` will raise a `NextStation::Error`.

#### Types

You can use all standard dry-types via `NextStation::Types`.

### Environment Configuration

NextStation's behavior can be environment-aware.

By default, it automatically detects the environment by checking for `RAILS_ENV`, `RACK_ENV`, `APP_ENV`, and `RUBY_ENV`.
It considers `development` and `dev` as development environments, and `production`, `prod`, `prd` as production-like.

### Simple Configuration

You can set the environment name directly:

```ruby
NextStation.configure do |config|
  config.environment = 'production'
  # or
  config.environment = ENV['MY_APP_ENV']
end
```

### Advanced Configuration

If you need to customize which names are considered "production" or "development", or which environment variables to
check, you can access the environment object properties:

```ruby
NextStation.configure do |config|
  # Consider 'staging' as a production-like environment
  config.environment.production_names << 'staging'
end
```

## License

TBD
