# Auth plumbing for API request specs. The plaintext token is only readable on
# the freshly created ApiKey instance, so the key is memoized per example and
# reused for both headers and record assertions.
module ApiHelpers
  def api_key
    @api_key ||= create(:api_key)
  end

  def api_user
    api_key.user
  end

  def api_organization
    api_key.organization
  end

  # @param key [ApiKey] a freshly created key whose plaintext #token is readable
  # @return [Hash] Authorization header for the given key
  def auth_headers(key = api_key)
    { "Authorization" => "Bearer #{key.token}" }
  end

  def json_body
    response.parsed_body
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
