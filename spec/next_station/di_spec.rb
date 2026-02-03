require "spec_helper"

RSpec.describe "Dependency Injection" do
  class Mailer
    def send_email
      "Email sent"
    end
  end

  class UserRepository
    def find(id)
      "User #{id}"
    end
  end

  let(:operation_class) do
    Class.new(NextStation::Operation) do
      depends mailer: -> { Mailer.new },
              repo: UserRepository.new

      result_at :res

      process do
        step :do_something
      end

      def do_something(state)
        state[:res] = {
          email: dependency(:mailer).send_email,
          user: dependency(:repo).find(1)
        }
        state
      end
    end
  end

  it "uses default dependencies" do
    operation = operation_class.new
    result = operation.call
    expect(result.value[:email]).to eq("Email sent")
    expect(result.value[:user]).to eq("User 1")
  end

  it "allows injecting dependencies via initialize" do
    mock_mailer = double("Mailer", send_email: "Mocked email")
    operation = operation_class.new(deps: { mailer: mock_mailer })
    result = operation.call
    expect(result.value[:email]).to eq("Mocked email")
    expect(result.value[:user]).to eq("User 1")
  end

  it "supports lazy dependencies" do
    lazy_called = 0
    op_class = Class.new(NextStation::Operation) do
      depends lazy_dep: -> { lazy_called += 1; "lazy" }
      result_at :res
      process { step :work }
      def work(state)
        state[:res] = dependency(:lazy_dep)
        state
      end
    end

    operation = op_class.new
    expect(lazy_called).to eq(0)
    operation.call
    expect(lazy_called).to eq(1)
    operation.call # Should probably memoize per instance? Or per call?
    # The requirement says "Operation.new accepts deps: {}". 
    # Usually DI in operations is per operation instance.
  end
  
  it "raises error for undeclared dependencies" do
    operation = NextStation::Operation.new
    expect { operation.dependency(:unknown) }.to raise_error(KeyError)
  end

  it "supports inheritance" do
    parent_op = Class.new(NextStation::Operation) do
      depends d1: "v1", d2: "v2"
    end
    child_op = Class.new(parent_op) do
      depends d2: "v2_overridden", d3: "v3"
    end

    op = child_op.new
    expect(op.dependency(:d1)).to eq("v1")
    expect(op.dependency(:d2)).to eq("v2_overridden")
    expect(op.dependency(:d3)).to eq("v3")
  end
end
