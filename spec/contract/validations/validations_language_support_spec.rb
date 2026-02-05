# frozen_string_literal: true

require 'spec_helper'
require 'dry-validation'

RSpec.describe 'ValidationsLanguageSupport' do
  let(:operation_class) do
    Class.new(NextStation::Operation) do
      # Configure the contract to use I18n as described in the README
      validate_with do
        config.messages.default_locale = :en

        params do
          required(:name).filled(:string)
        end
      end

      process { step :validation }
    end
  end

  let(:operation) { operation_class.new }

  describe 'Multi-language support for validation errors' do
    context 'when lang is :sp (Spanish)' do
      it 'returns localized validation error details from dry-validation' do
        result = operation.call({ name: '' }, { lang: :sp })

        expect(result).to be_failure
        expect(result.error.type).to eq(:validation)
        # result.error.details contains localized messages from dry-validation
        expect(result.error.details[:name]).to include('no puede estar vacío')
      end

      it 'returns the default NextStation validation message in Spanish' do
        result = operation.call({ name: '' }, { lang: :sp })

        expect(result.error.message).to eq('Uno o más parámetros son inválidos. Ver detalles de validación.')
      end
    end

    context 'when lang is :en (English)' do
      it 'returns localized validation error details in English' do
        result = operation.call({ name: '' }, { lang: :en })

        expect(result).to be_failure
        expect(result.error.type).to eq(:validation)
        expect(result.error.details[:name]).to include('must be filled')
      end

      it 'returns the default NextStation validation message in English' do
        result = operation.call({ name: '' }, { lang: :en })

        expect(result.error.message).to eq('One or more parameters are invalid. See validation details.')
      end
    end

    context 'when a custom error message is defined for :validation' do
      let(:operation_with_custom_errors) do
        Class.new(NextStation::Operation) do
          errors do
            error_type :validation do
              message en: "The provided data is invalid: %{errors}",
                      sp: "Los datos son inválidos: %{errors}"
            end
          end

          validate_with do
            config.messages.backend = :i18n
            params { required(:name).filled(:string) }
          end

          process { step :validation }
        end
      end

      it 'uses the custom localized message template from the errors DSL' do
        result = operation_with_custom_errors.new.call({ name: '' }, { lang: :sp })

        expect(result.error.message).to start_with('Los datos son inválidos')
      end
    end
  end
end
