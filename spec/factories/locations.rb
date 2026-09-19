# frozen_string_literal: true

FactoryBot.define do
  factory :location_state do
    sequence(:name) { |n| "Estado #{n}" }
    active { true }
    account
  end

  factory :location_city do
    sequence(:name) { |n| "Ciudad #{n}" }
    active { true }
    account
    location_state { association :location_state, account: account }
  end
end
