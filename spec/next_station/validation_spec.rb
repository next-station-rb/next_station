require "spec_helper"
require "dry-validation"

RSpec.describe "Input Validation (dry-validation)" do
  let(:operation_class) do
    Class.new(NextStation::Operation) do
      validate_with do
        params do
          required(:email).filled(:string, format?: /@/)
          required(:age).filled(:integer, gteq?: 18)
        end
      end

      process do
        step :validation
        step :persist
      end

      def persist(state)
        state[:result] = { coerced_age: state.params[:age], email: state.params[:email] }
        state
      end
    end
  end

  it "succeeds when params are valid and coerces values" do
    result = operation_class.new.call(email: "test@example.com", age: "25")
    expect(result).to be_success
    expect(result.value[:coerced_age]).to eq(25)
    expect(result.value[:email]).to eq("test@example.com")
  end

  it "fails when params are invalid with type :validation" do
    result = operation_class.new.call(email: "invalid", age: "17")
    expect(result).to be_failure
    expect(result.error.type).to eq(:validation)
    expect(result.error.details[:email]).to include("is in invalid format")
    expect(result.error.details[:age]).to include("must be greater than or equal to 18")
  end

  it "uses new default message when no custom error is defined" do
    result = operation_class.new.call(email: "invalid", age: "17")
    expect(result.error.message).to eq("One or more parameters are invalid. See validation details.")
  end

  it "allows overriding validation error message via errors DSL" do
    op_class = Class.new(operation_class) do
      errors do
        error_type :validation do
          message en: "Custom validation message: %{errors}"
        end
      end
    end

    result = op_class.new.call(email: "invalid", age: "25")
    expect(result.error.message).to start_with("Custom validation message:")
    expect(result.error.message).to include("email")
  end

  it "supports external contract classes" do
    contract_class = Class.new(Dry::Validation::Contract) do
      params do
        required(:token).filled(:string)
      end
    end

    op_class = Class.new(NextStation::Operation) do
      validate_with contract_class
      process { step :validation }
      def validation(state); super(state); state[:result] = "ok"; state; end
    end

    result = op_class.new.call(token: "")
    expect(result).to be_failure
    expect(result.error.details).to have_key(:token)
  end

  it "raises NextStation::ValidationError if step :validation is missing but enforced" do
    op_class = Class.new(NextStation::Operation) do
      validate_with { params { required(:a).filled } }
      force_validation!
      process { step :something_else }
      def something_else(state); state; end
    end

    expect { op_class.new.call(a: 1) }.to raise_error(NextStation::ValidationError, /missing from process block/)
  end

  it "raises NextStation::ValidationError if step :validation is called but no contract defined" do
    op_class = Class.new(NextStation::Operation) do
      process { step :validation }
    end

    expect { op_class.new.call }.to raise_error(NextStation::ValidationError, /no contract defined/)
  end

  it "allows skipping validation" do
    op_class = Class.new(operation_class) do
      skip_validation!
    end

    result = op_class.new.call(email: "invalid", age: "17")
    expect(result).to be_success
  end

  describe "Default message localization and inheritance" do
    it "supports Spanish default message" do
      result = operation_class.new.call({ email: "invalid", age: "17" }, { lang: :sp })
      expect(result.error.message).to eq("Uno o más parámetros son inválidos. Ver detalles de validación.")
    end

    it "retains parent errors when child defines its own errors" do
      parent_class = Class.new(NextStation::Operation) do
        errors do
          error_type :parent_error do
            message en: "Parent"
          end
        end
      end
      child_class = Class.new(parent_class) do
        errors do
          error_type :child_error do
            message en: "Child"
          end
        end
      end

      expect(child_class.error_definitions).to have_key(:parent_error)
      expect(child_class.error_definitions).to have_key(:child_error)
      expect(child_class.error_definitions).to have_key(:validation)
    end

    it "allows overriding default validation error in child" do
      custom_val_child = Class.new(NextStation::Operation) do
        errors do
          error_type :validation do
            message en: "Custom val"
          end
        end
        validate_with { params { required(:x).filled } }
        process { step :validation }
      end

      result = custom_val_child.new.call(x: nil)
      expect(result.error.message).to eq("Custom val")
    end
  end
end
