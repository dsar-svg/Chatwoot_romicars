# frozen_string_literal: true

json.payload @cities do |city|
  json.id city.id
  json.name city.name
  json.state do
    json.id city.location_state.id
    json.name city.location_state.name
  end
end

json.meta { json.count @cities.size }
