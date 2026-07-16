WebAuthn.configure do |config|
  config.rp_name = ENV.fetch("WEBAUTHN_RP_NAME", "Project Tracker")

  # The Relying Party ID is the domain passkeys are scoped to. "localhost" works
  # for development; production supplies the real host via an env var.
  config.rp_id = ENV.fetch("WEBAUTHN_RP_ID", "localhost")

  # The browser-reported origin must match exactly, scheme and port included.
  config.allowed_origins = [ ENV.fetch("WEBAUTHN_ORIGIN", "http://localhost:3000") ]

  config.encoding = :base64url
end
