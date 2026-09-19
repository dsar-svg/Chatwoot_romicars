# Turns a campaign's audience selectors into the contacts the campaign should reach.
#
# The audience column is a jsonb array of selectors, each tagged with a type:
#   { type: 'Label', id: 3 }
#   { type: 'VehicleBrand', id: 7 }
#   { type: 'VehicleModel', id: 21 }
#   { type: 'LocationState', id: 12 }
#   { type: 'LocationCity', id: 140 }
#
# Selectors of the same type are ORed (Chery or Toyota), and the types are ANDed with
# each other (a Chery AND living in Valencia). That mirrors how the campaign form
# presents them: one picker per category, each narrowing the audience further.
#
# Every selector travels by id, never by the stored text, so renaming a brand or a city
# doesn't silently empty a scheduled campaign.
class Campaigns::AudienceResolver
  BRAND_ATTRIBUTE = 'marca_vehiculo'.freeze
  MODEL_ATTRIBUTE = 'modelo_vehiculo'.freeze
  ESTADO_ATTRIBUTE = 'estado'.freeze
  CITY_ATTRIBUTE = 'city'.freeze

  pattr_initialize [:campaign!]

  def contacts
    # Fail closed. An audience that resolves to nothing selected must reach nobody —
    # returning the bare account scope here would blast the whole contact list.
    return account.contacts.none if no_selectors?

    scope = account.contacts
    scope = scope.tagged_with(label_titles, any: true) if label_titles.present?
    scope = by_custom_attribute(scope, BRAND_ATTRIBUTE, brand_names) if brand_names.present?
    scope = by_custom_attribute(scope, MODEL_ATTRIBUTE, model_names) if model_names.present?
    scope = by_custom_attribute(scope, ESTADO_ATTRIBUTE, state_names) if state_names.present?
    scope = by_additional_attribute(scope, CITY_ATTRIBUTE, city_names) if city_names.present?
    scope
  end

  private

  delegate :account, to: :campaign

  def no_selectors?
    [label_titles, brand_names, model_names, state_names, city_names].all?(&:blank?)
  end

  def audience
    @audience ||= Array(campaign.audience).map { |selector| selector.with_indifferent_access }
  end

  def ids_for(type)
    audience.select { |selector| selector[:type] == type }.pluck(:id).compact
  end

  def label_titles
    @label_titles ||= account.labels.where(id: ids_for('Label')).pluck(:title)
  end

  def brand_names
    @brand_names ||= account.vehicle_brands.where(id: ids_for('VehicleBrand')).pluck(:name)
  end

  def model_names
    @model_names ||= account.vehicle_models.where(id: ids_for('VehicleModel')).pluck(:name)
  end

  def state_names
    @state_names ||= account.location_states.where(id: ids_for('LocationState')).pluck(:name)
  end

  def city_names
    @city_names ||= account.location_cities.where(id: ids_for('LocationCity')).pluck(:name)
  end

  # The bot writes these straight from the catalogue tables, so the values line up.
  # Comparing trimmed and downcased keeps a hand-edited contact in the audience anyway.
  def by_custom_attribute(scope, key, names)
    scope.where(
      'LOWER(btrim(contacts.custom_attributes->>:key)) IN (:names)',
      key: key, names: names.map { |name| name.strip.downcase }
    )
  end

  # The city lives in the standard additional_attributes slot rather than a custom one,
  # so Chatwoot mirrors it into contacts.location and its own city filter sees it.
  def by_additional_attribute(scope, key, names)
    scope.where(
      'LOWER(btrim(contacts.additional_attributes->>:key)) IN (:names)',
      key: key, names: names.map { |name| name.strip.downcase }
    )
  end
end
