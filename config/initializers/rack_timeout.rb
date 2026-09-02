require 'rack-timeout'

# Set service timeout to 30 seconds.
# rack-timeout 0.6.x has no `Rack::Timeout.service_timeout=` class setter - it reads
# RACK_TIMEOUT_SERVICE_TIMEOUT from the environment when the middleware instance is built.
ENV['RACK_TIMEOUT_SERVICE_TIMEOUT'] ||= '30'

# Reduce noise by filtering state=ready and state=completed which are logged at INFO level
Rails.application.config.after_initialize do
  Rack::Timeout::Logger.level = Logger::ERROR
end
