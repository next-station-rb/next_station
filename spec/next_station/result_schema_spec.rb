require "spec_helper"
require "dry-struct"

RSpec.describe "Result Schema Enforcement" do
  let(:operation_class) do
    Class.new(NextStation::Operation) do
      result_at :user_data

      result_schema do
        attribute :name, NextStation::Types::String
        attribute :age,  NextStation::Types::Integer
      end

      process do
        step :set_data
      end

      def set_data(state)
        state[:user_data] = state.params
        state
      end
    end
  end

  it "casts the result to the defined struct on success" do
    op = operation_class.new
    result = op.call(name: "John", age: 30)

    expect(result).to be_success
    expect(result.value).to be_a(Dry::Struct)
    expect(result.value.name).to eq("John")
    expect(result.value.age).to eq(30)
  end

  it "raises NextStation::ResultShapeError when schema validation fails and preserves cause" do
    op = operation_class.new
    result = op.call(name: "John", age: "invalid")

    expect(result).to be_success
    begin
      result.value
    rescue NextStation::ResultShapeError => e
      expect(e.cause).to be_a(Dry::Struct::Error)
    end
  end

  it "allows disabling result schema enforcement" do
    op_class = Class.new(operation_class) do
      disable_result_schema
    end

    op = op_class.new
    result = op.call(name: "John", age: "invalid")

    expect(result).to be_success
    expect(result.value).to eq(name: "John", age: "invalid")
  end

  it "allows re-enabling result schema enforcement" do
    op_class = Class.new(operation_class) do
      disable_result_schema
      enforce_result_schema
    end

    op = op_class.new
    result = op.call(name: "John", age: "invalid")

    expect(result).to be_success
    expect { result.value }.to raise_error(NextStation::ResultShapeError)
  end

  it "supports nested attributes as in the example" do
    nested_op_class = Class.new(NextStation::Operation) do
      result_at :user_data

      result_schema do
        attribute :test, NextStation::Types::Integer
        attribute :address do
          attribute :city,   NextStation::Types::String
          attribute :street, NextStation::Types::String
        end
        attribute :nested_faker,  NextStation::Types::Any
      end

      process { step :set_data }
      def set_data(state); state[:user_data] = state.params; state; end
    end

    params = {
      test: 123,
      address: { city: "New York", street: "Wall St" },
      nested_faker: { anything: "goes" }
    }
    result = nested_op_class.new.call(params)

    expect(result.value.test).to eq(123)
    expect(result.value.address.city).to eq("New York")
  end
end
