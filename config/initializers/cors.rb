# config/initializers/cors.rb
# ref: https://github.com/cyu/rack-cors

# font cors issue with CDN
# Ref: https://stackoverflow.com/questions/56960709/rails-font-cors-policy
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    allowed_origins = ENV.fetch('ALLOWED_ORIGINS', 'romicars.com,app.romicars.com').split(',').map(&:strip)

    origins(*allowed_origins)

    resource '/packs/*', headers: :any, methods: [:get, :options]
    resource '/audio/*', headers: :any, methods: [:get, :options]
    # Make the public endpoints accessible to the frontend
    resource '/public/api/*', headers: ['Content-Type', 'Authorization'], methods: [:get, :post, :options]

    if ActiveModel::Type::Boolean.new.cast(ENV.fetch('CW_API_ONLY_SERVER', false)) || Rails.env.development?
      origins(*allowed_origins, localhost: nil, /127\.0\.0\.1/)
      resource '*', headers: ['Content-Type', 'Authorization', 'X-Auth-Token'], methods: :any, expose: %w[access-token client uid expiry]
    end

    if ActiveModel::Type::Boolean.new.cast(ENV.fetch('ENABLE_API_CORS', false))
      resource '/api/*', headers: ['Content-Type', 'Authorization', 'X-Auth-Token'], methods: :any, expose: %w[access-token client uid expiry]
    end
  end
end

################################################
######### Action Cable Related Config ##########
################################################

# Mount Action Cable outside main process or domain
# Rails.application.config.action_cable.mount_path = nil
# Rails.application.config.action_cable.url = 'wss://example.com/cable'

# Action Cable - configurar orígenes permitidos en vez de deshabilitar forgery protection
cable_allowed_origins = ENV.fetch('ALLOWED_ORIGINS', 'romicars.com,app.romicars.com').split(',').map(&:strip)
Rails.application.config.action_cable.allowed_request_origins = cable_allowed_origins.map { |origin| "https://#{origin}" }
