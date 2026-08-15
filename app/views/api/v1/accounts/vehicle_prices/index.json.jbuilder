# frozen_string_literal: true

json.payload @prices do |price|
  json.id price.id
  json.description price.description
  json.variant price.variant
  json.cost_usd price.cost_usd
  json.divisor price.divisor
  json.cost_bs price.cost_bs
  json.bolivares price.bolivares
  json.active price.active
  json.brand do
    json.id price.vehicle_brand.id
    json.name price.vehicle_brand.name
  end
  if price.vehicle_model
    json.model do
      json.id price.vehicle_model.id
      json.name price.vehicle_model.name
    end
  end
end

json.meta {
  json.count @prices.size
}
