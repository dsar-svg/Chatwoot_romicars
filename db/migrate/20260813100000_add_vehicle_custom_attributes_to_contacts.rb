# frozen_string_literal: true

class AddVehicleCustomAttributesToContacts < ActiveRecord::Migration[7.0]
  VEHICLE_ATTRS = [
    { key: 'marca_vehiculo', name: 'Marca de Vehículo' },
    { key: 'modelo_vehiculo', name: 'Modelo del Vehículo' }
  ].freeze

  def up
    Account.find_each do |account|
      VEHICLE_ATTRS.each do |attr|
        next if CustomAttributeDefinition.exists?(
          account: account,
          attribute_key: attr[:key],
          attribute_model: :contact_attribute
        )

        CustomAttributeDefinition.create!(
          account: account,
          attribute_display_name: attr[:name],
          attribute_key: attr[:key],
          attribute_model: :contact_attribute,
          attribute_display_type: :text
        )
      end
    end
  end

  def down
    CustomAttributeDefinition.where(
      attribute_key: VEHICLE_ATTRS.map { |a| a[:key] },
      attribute_model: :contact_attribute
    ).destroy_all
  end
end
