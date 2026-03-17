require 'next_station'

class UserOnboarding < NextStation::Operation

  # Define custom errors for this operation
  errors do
    error_type :invalid_email do
      # Error can be in multiple languages, using just English for now.
      message en: "Email is invalid. It must contain '@'."
    end
  end

  # Define the steps of the operation
  # this is the core of the Railway pattern
  # Steps are executed in the order they are defined
  process do
    step :validate_email
    step :send_welcome_email
    step :finalize_onboarding
  end
  # The state[:result] will contain the value of the operation in case of success
  result_at :result

  # Step 1: Validate email presence of "@"
  def validate_email(state)
    email = state.params[:email]
    unless email.to_s.include?("@")
      error!(type: :invalid_email) # here we invoke the custom error defined above
    end
    state
  end

  # Step 2: Send a welcome email
  def send_welcome_email(state)
    EmailSender.send(state.params[:email])
    state
  end

  # Step 3: Finalize onboarding and set result
  def finalize_onboarding(state)
    state[:result] = { status: "onboarded", email: state.params[:email] }
    state
  end
end

# Case 1: Successful Onboarding (Valid email), all 3 steps executed and the state[:result] set as value
operation = UserOnboarding.new.call(email: "alice@example.com")
operation.success? # => true
operation.value # => { status: "onboarded", email: "alice@example.com" }


# Case 2: Invalid Email Failure, step 1 fail and the error is:invalid_email is returned instead of a result
# no further steps are executed
operation = UserOnboarding.new.call(email: "bobexample.com")
operation.success? # => false
operation.failure? # => true
operation.error.type # => :invalid_email
operation.error.message # => "Email is invalid. It must contain '@'."
