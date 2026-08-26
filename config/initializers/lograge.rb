require 'lograge'

Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.custom_payload do |controller|
    # We only need user_id for API requests
    # might error out for other controller - ref: https://github.com/chatwoot/chatwoot/issues/6922
    user_id = controller&.try(:current_user)&.id if controller.is_a?(Api::BaseController) && controller&.try(:current_user).is_a?(User)
    {
      host: controller.request.host,
      remote_ip: controller.request.remote_ip,
      user_id: user_id
    }
  end

  config.lograge.custom_options = lambda do |event|
    param_exceptions = %w[controller action format id]
    {
      time: event.time,
      request_id: event.payload[:request_id],
      params: event.payload[:params]&.except(*param_exceptions)
    }
  end

  config.lograge.ignore_custom = lambda do |event|
    # ignore update_presence  events in log
    return true if event.payload[:channel_class] == 'RoomChannel'
  end
end
