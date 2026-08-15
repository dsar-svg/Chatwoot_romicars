# frozen_string_literal: true

json.payload @rates do |rate|
  json.id rate.id
  json.rate rate.rate
  json.equiv_13 rate.equiv_13
  json.effective_date rate.effective_date
  json.source rate.source
  json.created_at rate.created_at
end

json.meta {
  json.count @rates.size
}
