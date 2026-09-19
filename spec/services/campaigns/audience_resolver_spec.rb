require 'rails_helper'

describe Campaigns::AudienceResolver do
  subject(:resolved) { described_class.new(campaign: campaign).contacts }

  let(:account) { create(:account) }
  let(:label) { create(:label, account: account) }
  let(:chery) { create(:vehicle_brand, account: account, name: 'Chery') }
  let(:toyota) { create(:vehicle_brand, account: account, name: 'Toyota') }
  let(:arauca) { create(:vehicle_model, account: account, vehicle_brand: chery, name: 'Arauca') }
  let(:carabobo) { create(:location_state, account: account, name: 'Carabobo') }
  let(:valencia) { create(:location_city, account: account, location_state: carabobo, name: 'Valencia') }

  let(:campaign) { create(:campaign, :whatsapp, account: account, audience: audience) }

  def contact_with(attributes = {}, city: nil)
    create(:contact, account: account,
                     custom_attributes: attributes,
                     additional_attributes: city ? { 'city' => city } : {})
  end

  context 'when the audience has no usable selector' do
    let(:audience) { [] }

    it 'reaches nobody rather than the whole account' do
      contact_with('marca_vehiculo' => 'Chery')

      expect(resolved).to be_empty
    end
  end

  context 'when filtering by vehicle brand' do
    let(:audience) { [{ 'type' => 'VehicleBrand', 'id' => chery.id }] }

    it 'returns only contacts driving that brand' do
      chery_driver = contact_with('marca_vehiculo' => 'Chery')
      contact_with('marca_vehiculo' => 'Toyota')

      expect(resolved).to contain_exactly(chery_driver)
    end

    it 'ignores the casing a contact was saved with' do
      hand_edited = contact_with('marca_vehiculo' => 'chery')

      expect(resolved).to contain_exactly(hand_edited)
    end
  end

  context 'when several brands are selected' do
    let(:audience) do
      [{ 'type' => 'VehicleBrand', 'id' => chery.id }, { 'type' => 'VehicleBrand', 'id' => toyota.id }]
    end

    it 'adds them together' do
      chery_driver = contact_with('marca_vehiculo' => 'Chery')
      toyota_driver = contact_with('marca_vehiculo' => 'Toyota')
      contact_with('marca_vehiculo' => 'Ford')

      expect(resolved).to contain_exactly(chery_driver, toyota_driver)
    end
  end

  context 'when filtering by state' do
    let(:audience) { [{ 'type' => 'LocationState', 'id' => carabobo.id }] }

    it 'returns contacts whose estado matches the catalogue entry' do
      local = contact_with('estado' => 'Carabobo')
      contact_with('estado' => 'Aragua')

      expect(resolved).to contain_exactly(local)
    end

    it 'keeps a hand-edited contact whose casing drifted' do
      hand_edited = contact_with('estado' => 'carabobo')

      expect(resolved).to contain_exactly(hand_edited)
    end
  end

  context 'when filtering by city' do
    let(:audience) { [{ 'type' => 'LocationCity', 'id' => valencia.id }] }

    # The city lives in the standard additional_attributes slot, not a custom one.
    it 'reads the city off additional_attributes' do
      local = contact_with({}, city: 'Valencia')
      contact_with({}, city: 'Maracay')

      expect(resolved).to contain_exactly(local)
    end
  end

  context 'when brand and city are combined' do
    let(:audience) do
      [{ 'type' => 'VehicleBrand', 'id' => chery.id }, { 'type' => 'LocationCity', 'id' => valencia.id }]
    end

    it 'narrows to contacts matching both, not either' do
      both = create(:contact, account: account,
                              custom_attributes: { 'marca_vehiculo' => 'Chery' },
                              additional_attributes: { 'city' => 'Valencia' })
      create(:contact, account: account,
                       custom_attributes: { 'marca_vehiculo' => 'Chery' },
                       additional_attributes: { 'city' => 'Maracay' })
      create(:contact, account: account,
                       custom_attributes: { 'marca_vehiculo' => 'Toyota' },
                       additional_attributes: { 'city' => 'Valencia' })

      expect(resolved).to contain_exactly(both)
    end
  end

  context 'when a label is combined with a model' do
    let(:audience) do
      [{ 'type' => 'Label', 'id' => label.id }, { 'type' => 'VehicleModel', 'id' => arauca.id }]
    end

    it 'requires both the label and the model' do
      matching = contact_with('modelo_vehiculo' => 'Arauca')
      matching.update_labels([label.title])
      contact_with('modelo_vehiculo' => 'Arauca')
      labelled_only = contact_with('modelo_vehiculo' => 'Corolla')
      labelled_only.update_labels([label.title])

      expect(resolved).to contain_exactly(matching)
    end
  end

  context 'when the selected brand was deleted' do
    let(:audience) { [{ 'type' => 'VehicleBrand', 'id' => 0 }] }

    it 'reaches nobody instead of everybody' do
      contact_with('marca_vehiculo' => 'Chery')

      expect(resolved).to be_empty
    end
  end
end
