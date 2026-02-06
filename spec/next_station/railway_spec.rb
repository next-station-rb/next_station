# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Railway Pattern (Results & Errors)' do
  class CreateUser < NextStation::Operation
    result_at :user

    errors do
      error_type :email_taken do
        message en: 'Email %<email>s is taken'
        message sp: 'El correo %<email>s ya existe'
        help_url 'http://example.com/support/article/4278671'
      end

      error_type :invalid_data do
        message en: 'Invalid data provided'
      end
    end

    process do
      step :check_email
      step :create_user
    end

    def check_email(state)
      if state.params[:email] == 'taken@example.com'
        error!(type: :email_taken, msg_keys: { email: state.params[:email] }, details: { existing_email: true })
      end
      state
    end

    def create_user(state)
      state[:user] = { id: 1, email: state.params[:email] }
      state
    end
  end

  describe 'Success result' do
    it 'returns a success result with the value at result_at key' do
      result = CreateUser.new.call({ email: 'new@example.com' })

      expect(result).to be_success
      expect(result.value).to eq({ id: 1, email: 'new@example.com' })
    end
  end

  describe 'Failure result and halting' do
    it 'halts execution and returns a failure result with error details' do
      result = CreateUser.new.call({ email: 'taken@example.com' })

      expect(result).to be_failure
      expect(result.error.type).to eq(:email_taken)
      expect(result.error.message).to eq('Email taken@example.com is taken')
      expect(result.error.help_url).to eq('http://example.com/support/article/4278671')
      expect(result.error.details).to eq({ existing_email: true })
    end

    it 'supports different languages for the error message' do
      # Assuming we can pass lang in context or as a separate argument.
      # The requirements say: "Support to print the error message in multiple langs with default to english"
      # and "The error sould support also define the desired lang with fallback to english"

      result = CreateUser.new.call({ email: 'taken@example.com' }, { lang: :sp })

      expect(result).to be_failure
      expect(result.error.message).to eq('El correo taken@example.com ya existe')
    end

    it 'falls back to English if language is not supported' do
      result = CreateUser.new.call({ email: 'taken@example.com' }, { lang: :fr })

      expect(result).to be_failure
      expect(result.error.message).to eq('Email taken@example.com is taken')
    end
  end

  describe 'Error DSL Validations' do
    it 'raises an exception if English message is missing' do
      expect do
        Class.new(NextStation::Operation) do
          errors do
            error_type :no_en do
              message sp: 'No hay mensaje en inglés'
            end
          end
        end
      end.to raise_error(StandardError, /English message is required/)
    end

    it 'raises an exception if more than one help_url is given' do
      expect do
        Class.new(NextStation::Operation) do
          errors do
            error_type :double_url do
              message en: 'Error'
              help_url 'http://url1.com'
              help_url 'http://url2.com'
            end
          end
        end
      end.to raise_error(StandardError, /Only one help_url is allowed/)
    end

    it 'raises an exception if an undeclared error type is used' do
      op_class = Class.new(NextStation::Operation) do
        process { step :boom }
        def boom(_state)
          error!(type: :unknown)
        end
      end

      expect { op_class.new.call }.to raise_error(StandardError, /Undeclared error type: unknown/)
    end
  end
end
