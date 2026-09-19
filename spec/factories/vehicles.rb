# frozen_string_literal: true

FactoryBot.define do
  factory :vehicle_brand do
    sequence(:name) { |n| "Brand #{n}" }
    active { true }
    account
  end

  factory :vehicle_model do
    sequence(:name) { |n| "Model #{n}" }
    active { true }
    account
    vehicle_brand { association :vehicle_brand, account: account }
  end
end
