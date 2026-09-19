# frozen_string_literal: true

json.payload @states do |state|
  json.id state.id
  json.name state.name
end

json.meta { json.count @states.size }
