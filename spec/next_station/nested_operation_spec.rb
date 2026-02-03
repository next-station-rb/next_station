require "spec_helper"

RSpec.describe "Nested Operations" do
  let(:child_op_class) do
    Class.new(NextStation::Operation) do
      errors do
        error_type :child_error do
          message en: "Child error with key: %{key}"
        end
      end

      process do
        step :process_child
      end

      def process_child(state)
        if state.params[:fail]
          error!(type: :child_error, msg_keys: { key: state.params[:key] }, details: { some: "detail" })
        end
        state[:result] = "Child success: #{state.context[:current_user]}"
        state
      end
    end
  end

  let(:parent_op_class) do
    child_klass = child_op_class
    Class.new(NextStation::Operation) do
      result_at :child_output

      errors do
        error_type :child_error do
          message en: "Parent intercepted: %{key}"
        end
      end

      process do
        step :call_child
      end

      define_method :call_child do |state|
        call_operation(
          state,
          child_klass,
          with_params: ->(s) { { fail: s.params[:fail_child], key: s.params[:key] } },
          store_result_in_key: :child_output
        )
      end
    end
  end

  describe "#call_operation" do
    it "shares context with the child operation" do
      result = parent_op_class.new.call({ fail_child: false }, { current_user: "Alice" })
      expect(result).to be_success
      expect(result.value).to eq("Child success: Alice")
    end

    it "stores result in specified key" do
      result = parent_op_class.new.call({ fail_child: false }, { current_user: "Alice" })
      expect(result.value).to eq("Child success: Alice")
    end

    it "intercepts error when parent defines the same error type" do
      result = parent_op_class.new.call({ fail_child: true, key: "secret" })
      expect(result).to be_failure
      expect(result.error.type).to eq(:child_error)
      expect(result.error.message).to eq("Parent intercepted: secret")
      expect(result.error.msg_keys).to eq({ key: "secret" })
      expect(result.error.details).to eq({ some: "detail" })
    end

    it "propagates error transparently when parent does NOT define the error type" do
      klass = child_op_class
      parent_no_intercept = Class.new(NextStation::Operation) do
        result_at :child_output
        process { step :call_child }
        define_method :call_child do |state|
          call_operation(state, klass, with_params: { fail: true, key: "raw" }, store_result_in_key: :child_output)
        end
      end

      result = parent_no_intercept.new.call
      expect(result.error&.type).to eq(:child_error), "Expected :child_error but got #{result.error&.type}: #{result.error&.message}"
      expect(result.error.message).to eq("Child error with key: raw")
      expect(result.error.msg_keys).to eq({ key: "raw" })
    end

    it "supports dependency injection propagation" do
      child_with_di = Class.new(NextStation::Operation) do
        depends repo: -> { "default_repo" }
        process { step :check_di }
        def check_di(state)
          state[:result] = dependency(:repo)
          state
        end
      end

      parent_op = Class.new(NextStation::Operation) do
        result_at :di_res
        process { step :call_child }
        define_method :call_child do |state|
          call_operation(state, child_with_di, with_params: {}, store_result_in_key: :di_res)
        end
      end

      # Test default DI
      expect(parent_op.new.call.value).to eq("default_repo")

      # Test injected DI
      expect(parent_op.new(deps: { repo: "mock_repo" }).call.value).to eq("mock_repo")
    end

    it "works with already instantiated operations" do
      child_instance = child_op_class.new
      parent_op = Class.new(NextStation::Operation) do
        result_at :res
        process { step :call_child }
        define_method :call_child do |state|
          call_operation(state, child_instance, with_params: { fail: false }, store_result_in_key: :res)
        end
      end

      result = parent_op.new.call({}, { current_user: "Bob" })
      expect(result.value).to eq("Child success: Bob")
    end

    it "triggers Halt mechanism so parent retry_if can catch it" do
      child_failing = Class.new(NextStation::Operation) do
        errors { error_type(:fail) { message en: "Fail" } }
        process { step :always_fail }
        def always_fail(state)
          error!(type: :fail)
        end
      end

      parent_op = Class.new(NextStation::Operation) do
        attr_reader :calls
        def initialize(deps: {})
          super
          @calls = 0
        end

        process do
          step :call_child, attempts: 3, retry_if: ->(state, error) { true }
        end

        define_method :call_child do |state|
          @calls += 1
          call_operation(state, child_failing, with_params: {})
        end
      end

      op = parent_op.new
      result = op.call
      expect(result).to be_failure
      expect(op.calls).to eq(3)
    end
  end
end
