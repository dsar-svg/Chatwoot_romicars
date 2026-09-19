# frozen_string_literal: true

namespace :locations do
  CATALOGUE_PATH = Rails.root.join('db/seeds/venezuela_locations.yml')

  desc 'Load the Venezuelan state/city catalogue. ACCOUNT_ID=1 for one account, otherwise every account.'
  task seed: :environment do
    catalogue = YAML.load_file(CATALOGUE_PATH)
    accounts = ENV['ACCOUNT_ID'].present? ? Account.where(id: ENV['ACCOUNT_ID']) : Account.all

    abort "No account matched ACCOUNT_ID=#{ENV.fetch('ACCOUNT_ID', nil)}" if accounts.empty?

    accounts.find_each do |account|
      created_states = 0
      created_cities = 0

      catalogue.each do |state_name, city_names|
        state = LocationState.find_or_create_by!(account: account, name: state_name)
        created_states += 1 if state.previously_new_record?

        Array(city_names).each do |city_name|
          city = LocationCity.find_or_create_by!(
            account: account,
            location_state: state,
            name: city_name
          )
          created_cities += 1 if city.previously_new_record?
        end
      end

      puts format(
        '[locations:seed] cuenta %<id>s: +%<estados>s estados, +%<ciudades>s ciudades (total %<te>s / %<tc>s)',
        id: account.id, estados: created_states, ciudades: created_cities,
        te: account.location_states.count, tc: account.location_cities.count
      )
    end
  end
end
