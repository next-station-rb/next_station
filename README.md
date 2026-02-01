# NextStation

NextStation is a lightweight, flexible framework for building service objects (Operations) in Ruby. It provides a clean DSL to define business processes, manage state, and handle flow control.

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

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
