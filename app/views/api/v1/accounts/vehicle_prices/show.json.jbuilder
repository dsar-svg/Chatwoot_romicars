# frozen_string_literal: true

json.payload do
  json.id @price.id
  json.description @price.description
  json.variant @price.variant
  json.cost_usd @price.cost_usd
  json.divisa @price.divisa
  json.monto_bs @price.monto_bs
  json.bolivares @price.bolivares
  json.active @price.active
  json.synonyms @price.synonyms
  json.brand do
    json.id @price.vehicle_brand.id
    json.name @price.vehicle_brand.name
  end
  if @price.vehicle_model
    json.model do
      json.id @price.vehicle_model.id
      json.name @price.vehicle_model.name
    end
  end
  json.created_at @price.created_at
  json.updated_at @price.updated_at
end
