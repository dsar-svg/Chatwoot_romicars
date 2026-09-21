# frozen_string_literal: true

FactoryBot.define do
  factory :product_inquiry do
    account
    conversation { association :conversation, account: account }
    repuesto_buscado { 'kit de clutch' }
    encontrado { true }

    trait :not_found do
      encontrado { false }
    end
  end
end
