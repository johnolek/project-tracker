class ApiKey < ApplicationRecord
  TOKEN_PREFIX = "pt_"

  # @!attribute [r] token
  #   The plaintext token, readable only on the instance that just generated it
  #   (i.e. immediately after create). Only the SHA-256 digest is persisted, so
  #   reloaded or later-fetched records return nil — show it to the user once.
  #   @return [String, nil]
  attr_reader :token

  belongs_to :user
  belongs_to :organization

  validates :name, presence: true

  before_validation :generate_token, on: :create

  # Looks up a key by its plaintext token.
  #
  # @param token [String, nil] the plaintext token presented by an API client
  # @return [ApiKey, nil] the matching key, or nil for blank/unknown tokens
  def self.authenticate(token)
    return nil if token.blank?

    find_by(token_digest: Digest::SHA256.hexdigest(token))
  end

  # Records that the key was just used. Skips the write when last_used_at is
  # under 60 seconds old, since the API calls this on every request.
  #
  # @return [void]
  def touch_last_used
    return if last_used_at.present? && last_used_at > 60.seconds.ago

    update_column(:last_used_at, Time.current)
  end

  private

  def generate_token
    return if token_digest.present?

    @token = "#{TOKEN_PREFIX}#{SecureRandom.base58(32)}"
    self.token_digest = Digest::SHA256.hexdigest(@token)
    self.last4 = @token.last(4)
  end
end
