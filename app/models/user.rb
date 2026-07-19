class User < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships
  has_many :credentials, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :comparisons, dependent: :destroy
  has_many :api_keys, dependent: :destroy
  belongs_to :default_organization, class_name: "Organization", optional: true

  normalizes :email, with: ->(email) { email.strip.downcase.presence }

  validates :username, presence: true, uniqueness: true
  validates :webauthn_id, presence: true, uniqueness: true
  validates :email, presence: true, on: :create
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }, allow_nil: true

  # Signed, expiring token for the email magic-link sign-in (also the domain-
  # change / lost-passkey bridge). Bound to the current email so changing it
  # invalidates any outstanding links.
  generates_token_for :email_login, expires_in: 20.minutes do
    email
  end

  after_create :create_personal_organization

  private

  def create_personal_organization
    organization = Organization.create!(name: "#{username}'s Organization")
    memberships.create!(organization: organization, role: "owner")
    update_column(:default_organization_id, organization.id)
  end
end
