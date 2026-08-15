# frozen_string_literal: true

json.payload do
  json.id @model.id
  json.name @model.name
  json.active @model.active
  json.brand do
    json.id @model.vehicle_brand.id
    json.name @model.vehicle_brand.name
  end
  json.created_at @model.created_at
  json.updated_at @model.updated_at
end
