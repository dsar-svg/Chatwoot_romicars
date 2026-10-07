# frozen_string_literal: true

json.payload @prices do |price|
  json.id price.id
  json.description price.description
  json.variant price.variant
  json.cost_usd price.cost_usd
  json.divisa price.divisa
  json.monto_bs price.monto_bs
  json.bolivares price.bolivares
  json.active price.active
  json.available price.available
  json.synonyms price.synonyms
  json.kind price.kind
  json.details price.details
  json.ends_on price.ends_on
  if price.vehicle_brand
    json.brand do
      json.id price.vehicle_brand.id
      json.name price.vehicle_brand.name
    end
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
