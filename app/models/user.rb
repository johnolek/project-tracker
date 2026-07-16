class User < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships
  has_many :credentials, dependent: :destroy
  has_many :comments, dependent: :destroy
  belongs_to :default_organization, class_name: "Organization", optional: true

  validates :username, presence: true, uniqueness: true
  validates :webauthn_id, presence: true, uniqueness: true

  after_create :create_personal_organization

  private

  def create_personal_organization
    organization = Organization.create!(name: "#{username}'s Organization")
    memberships.create!(organization: organization, role: "owner")
    update_column(:default_organization_id, organization.id)
  end
end
