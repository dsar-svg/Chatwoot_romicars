# frozen_string_literal: true

class AddEstadoCustomAttributeToContacts < ActiveRecord::Migration[7.0]
  # Inlined on purpose: a migration is a frozen snapshot and must not depend on a seed
  # file that keeps changing. The live catalogue lives in location_states; this list only
  # drives the dropdown shown on the contact sidebar.
  ESTADOS = [
    'Amazonas', 'Anzoátegui', 'Apure', 'Aragua', 'Barinas', 'Bolívar', 'Carabobo', 'Cojedes',
    'Delta Amacuro', 'Distrito Capital', 'Falcón', 'Guárico', 'La Guaira', 'Lara', 'Mérida',
    'Miranda', 'Monagas', 'Nueva Esparta', 'Portuguesa', 'Sucre', 'Táchira', 'Trujillo',
    'Yaracuy', 'Zulia'
  ].freeze

  def up
    Account.find_each do |account|
      next if CustomAttributeDefinition.exists?(
        account: account,
        attribute_key: 'estado',
        attribute_model: :contact_attribute
      )

      CustomAttributeDefinition.create!(
        account: account,
        attribute_display_name: 'Estado',
        attribute_key: 'estado',
        attribute_model: :contact_attribute,
        attribute_display_type: :list,
        attribute_values: ESTADOS
      )
    end
  end

  def down
    CustomAttributeDefinition.where(
      attribute_key: 'estado',
      attribute_model: :contact_attribute
    ).destroy_all
  end
end
