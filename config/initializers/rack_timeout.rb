require 'rack-timeout'

# Set service timeout to 30 seconds
Rack::Timeout.service_timeout = 30

# Reduce noise by filtering state=ready and state=completed which are logged at INFO level
Rails.application.config.after_initialize do
  Rack::Timeout::Logger.level = Logger::ERROR
end
