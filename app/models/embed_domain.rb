class EmbedDomain < ApplicationRecord
  # Origins the browser can send are http(s) only; the widget loader derives the
  # frame src from a script tag, so only these two schemes ever reach here.
  ALLOWED_SCHEMES = %w[http https].freeze

  # A bare host, optionally with a port ("chesshair.com", "localhost:5173").
  # No scheme, path, or userinfo — the allowlist matches on host authority
  # alone, so http and https of the same host share one row.
  HOST_FORMAT = /\A(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)*(?::\d{1,5})?\z/

  belongs_to :organization
  belongs_to :project

  normalizes :host, with: ->(host) { host.to_s.strip.downcase }

  validates :host, presence: true,
                   uniqueness: { case_sensitive: false },
                   format: { with: HOST_FORMAT, message: "must be a bare host like example.com or localhost:5173" }
  validate :project_in_organization

  # Extracts the allowlist host key ("chesshair.com", "localhost:5173") from a
  # page origin. The port is kept only when it isn't the scheme's default, so
  # https://chesshair.com and http://chesshair.com both key to "chesshair.com"
  # while http://localhost:5173 keeps its port.
  #
  # @param origin [String, nil] a page origin like "https://chesshair.com"
  # @return [String, nil] the lowercase host[:port] key, or nil when unparseable
  def self.host_key_for(origin)
    uri = URI.parse(origin.to_s)
    return nil unless ALLOWED_SCHEMES.include?(uri.scheme) && uri.host.present?

    host = uri.host.downcase
    uri.port && uri.port != uri.default_port ? "#{host}:#{uri.port}" : host
  rescue URI::InvalidURIError
    nil
  end

  # Rebuilds a clean origin ("scheme://host[:port]") from a page origin so the
  # value placed in the frame's frame-ancestors CSP is derived from parsed
  # components rather than the raw, attacker-controllable request param.
  #
  # @param origin [String, nil]
  # @return [String, nil]
  def self.normalized_origin(origin)
    uri = URI.parse(origin.to_s)
    return nil unless ALLOWED_SCHEMES.include?(uri.scheme) && uri.host.present?

    port = uri.port && uri.port != uri.default_port ? ":#{uri.port}" : ""
    "#{uri.scheme}://#{uri.host.downcase}#{port}"
  rescue URI::InvalidURIError
    nil
  end

  # Resolves a page origin to its allowlisted domain, if any. The exact host
  # (including port) must match a stored row.
  #
  # @param origin [String, nil]
  # @return [EmbedDomain, nil]
  def self.for_origin(origin)
    key = host_key_for(origin)
    key && find_by(host: key)
  end

  private

  def project_in_organization
    return if project.nil? || organization.nil?
    return if project.organization_id == organization_id

    errors.add(:project, "must belong to this organization")
  end
end
