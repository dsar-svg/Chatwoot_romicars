# frozen_string_literal: true

json.payload do
  json.id @brand.id
  json.name @brand.name
  json.active @brand.active
  json.models_count @brand.vehicle_models.count
  json.prices_count @brand.vehicle_prices.count
  json.created_at @brand.created_at
  json.updated_at @brand.updated_at
end
