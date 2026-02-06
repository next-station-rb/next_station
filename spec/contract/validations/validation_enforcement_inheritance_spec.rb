# frozen_string_literal: true

require 'spec_helper'

# Key Behaviors Verified:
#  1. Inheritance of Enforcement: If force_validation! is called in a base class, any child that defines a process block
#     without a step :validation will raise a NextStation::ValidationError at runtime.
#  2. Override via skip_validation!: A subclass can explicitly opt out of enforcement by calling skip_validation!,
#     which is useful for internal or utility operations that inherit from a secured base.
#  3. Recursive Check: The enforcement check correctly traverses the inheritance tree to find the "last defined"
#     state of the enforcement flag.
#  4. Runtime Protection: The error is raised during the .call invocation, preventing the operation from executing any
#     business logic if the required safety check is missing.
#
RSpec.describe 'Validation Enforcement Inheritance' do
  # Parent class that enforces validation for all its descendants
  let(:parent_operation) do
    Class.new(NextStation::Operation) do
      force_validation!

      validate_with do
        params { required(:token).filled(:string) }
      end
    end
  end

  describe 'Child inheritance of enforcement' do
    it 'raises NextStation::ValidationError in child when :validation step is missing' do
      child_class = Class.new(parent_operation) do
        process do
          step :some_business_logic
        end

        def some_business_logic(state)
          state[:result] = 'logic executed'
          state
        end
      end

      # Even if the child doesn't call force_validation! explicitly,
      # it inherits the enforcement from the parent.
      expect { child_class.new.call(token: 'valid') }.to raise_error(
        NextStation::ValidationError,
        /Validation is enforced but step :validation is missing/
      )
    end

    # TODO: -  ¿is this odd?
    it 'succeeds in child when :validation step is correctly added' do
      child_class = Class.new(parent_operation) do
        process do
          step :validation
          step :some_business_logic
        end

        def some_business_logic(state)
          state[:result] = 'success'
          state
        end
      end

      result = child_class.new.call(token: 'valid')
      expect(result).to be_success
      expect(result.value).to eq('success')
    end

    it 'allows a grandchild to skip validation even if the grandparent enforced it' do
      child_class = Class.new(parent_operation)

      grandchild_class = Class.new(child_class) do
        skip_validation!

        process do
          step :direct_logic
        end

        def direct_logic(state)
          state[:result] = 'skipped and worked'
          state
        end
      end

      # Should not raise ValidationError because skip_validation! overrides enforcement
      result = grandchild_class.new.call(token: 'anything')
      expect(result).to be_success
      expect(result.value).to eq('skipped and worked')
    end

    it 're-enforces validation if a child tries to skip and a grandchild forces it again' do
      child_class = Class.new(parent_operation) do
        skip_validation!
      end

      grandchild_class = Class.new(child_class) do
        force_validation!
        process { step :logic }

        def logic(state)
          state[:result] = 'ok'
          state
        end
      end

      expect { grandchild_class.new.call }.to raise_error(NextStation::ValidationError)
    end
  end
end
