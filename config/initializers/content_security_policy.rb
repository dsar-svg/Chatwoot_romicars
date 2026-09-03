# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy
# For further information see the following documentation
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.font_src    :self, :data
  policy.img_src     :self, :data, :https
  policy.object_src  :none
  # unsafe-eval is required by the frontend bundle (vue-i18n compiles locale messages at
  # runtime via `new Function`); a nonce can't cover eval, only inline <script> tags.
  policy.script_src  :self, :unsafe_eval
  policy.style_src   :self, :unsafe_inline
  policy.frame_ancestors :self

  # WebSocket para Action Cable
  policy.connect_src :self, 'wss:', 'ws:'

  # Reportar violaciones (opcional, habilitar en producción)
  # policy.report_uri "/csp-violation-report-endpoint"
end

# Required for the inline <script> blocks that bootstrap window.chatwootConfig /
# window.portalConfig (see app/views/layouts/vueapp.html.erb and the portal layouts) -
# without a nonce_generator, script-src :self blocks those and the app never boots.
Rails.application.config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }

# Set the nonce only to specific directives
Rails.application.config.content_security_policy_nonce_directives = %w(script-src)

# Report CSP violations to a specified URI
# For further information see the following documentation:
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy-Report-Only
# Rails.application.config.content_security_policy_report_only = true
