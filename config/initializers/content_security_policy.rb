# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy
# For further information see the following documentation
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

# Connecting a Facebook page, an Instagram account or a WhatsApp number all run through
# Meta's JS SDK, which the browser has to fetch, talk to and open a popup for. Under a
# bare `script-src 'self'` the SDK script is refused before it is even requested, so
# `loadFacebookSdk` waits on a `load` event that never fires and the connect screen sits
# on "Authenticating you with Facebook..." forever. The three directives below are what
# the SDK needs; anything narrower fails at a different step of the same flow.
META_SDK_SRC = 'https://connect.facebook.net'.freeze
META_API_SRC = %w[https://graph.facebook.com https://www.facebook.com].freeze
META_FRAME_SRC = %w[https://www.facebook.com https://web.facebook.com https://staticxx.facebook.com].freeze

Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.font_src    :self, :data
  policy.img_src     :self, :data, :https
  policy.object_src  :none
  # unsafe-eval is required by the frontend bundle (vue-i18n compiles locale messages at
  # runtime via `new Function`); a nonce can't cover eval, only inline <script> tags.
  policy.script_src  :self, :unsafe_eval, META_SDK_SRC
  policy.style_src   :self, :unsafe_inline
  policy.frame_ancestors :self

  # The login popup and the embedded signup flow are Facebook-hosted frames. Without an
  # explicit frame-src they fall back to default-src :self and never open.
  policy.frame_src :self, *META_FRAME_SRC

  # WebSocket para Action Cable, and the SDK's own calls to the Graph API.
  policy.connect_src :self, 'wss:', 'ws:', META_SDK_SRC, *META_API_SRC

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
