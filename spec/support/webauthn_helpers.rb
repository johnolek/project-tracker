require "webauthn/fake_client"

# Drives the passkey endpoints in request specs using the webauthn gem's
# FakeClient, which simulates a real authenticator without a browser.
module WebauthnHelpers
  def webauthn_origin
    WebAuthn.configuration.allowed_origins.first
  end

  def fake_webauthn_client
    @fake_webauthn_client ||= WebAuthn::FakeClient.new(webauthn_origin)
  end

  # Runs the full two-step registration handshake and leaves the session signed in.
  def register_passkey(username:, client: fake_webauthn_client)
    post signup_options_path, params: { username: username }, as: :json
    challenge = response.parsed_body["challenge"]
    credential = client.create(challenge: challenge, user_verified: true)
    post signup_path, params: { credential: credential }, as: :json
  end

  # Runs the full two-step authentication handshake for an already-registered passkey.
  def authenticate_passkey(username:, client: fake_webauthn_client)
    post login_options_path, params: { username: username }, as: :json
    challenge = response.parsed_body["challenge"]
    assertion = client.get(challenge: challenge, user_verified: true)
    post login_path, params: { credential: assertion }, as: :json
  end
end

RSpec.configure do |config|
  config.include WebauthnHelpers, type: :request
end
