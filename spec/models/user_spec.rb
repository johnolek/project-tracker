require "rails_helper"

RSpec.describe User, type: :model do
  subject { create(:user) }

  it { is_expected.to validate_presence_of(:username) }
  it { is_expected.to validate_presence_of(:webauthn_id) }

  it "requires a unique username" do
    create(:user, username: "alice")
    expect(build(:user, username: "alice")).not_to be_valid
  end

  it "requires a unique webauthn_id" do
    existing = create(:user)
    expect(build(:user, webauthn_id: existing.webauthn_id)).not_to be_valid
  end

  it { is_expected.to have_many(:memberships).dependent(:destroy) }
  it { is_expected.to have_many(:organizations).through(:memberships) }
  it { is_expected.to have_many(:credentials).dependent(:destroy) }
  it { is_expected.to have_many(:comments).dependent(:destroy) }
  it { is_expected.to belong_to(:default_organization).class_name("Organization").optional }

  describe "personal organization on signup" do
    let(:user) { create(:user, username: "alice") }

    it "creates a personal organization named after the user" do
      expect(user.default_organization).to be_present
      expect(user.default_organization.name).to eq("alice's Organization")
    end

    it "creates a single owner membership in that organization" do
      membership = user.memberships.sole
      expect(membership.organization).to eq(user.default_organization)
      expect(membership.role).to eq("owner")
    end

    it "seeds the default statuses for the personal organization" do
      seeded = user.default_organization.statuses.ordered.map { |status| [ status.name, status.category ] }
      expect(seeded).to eq([ [ "New", "open" ], [ "In Progress", "in_progress" ], [ "Completed", "done" ] ])
    end

    it "always leaves the user with at least one organization" do
      expect(user.organizations).to include(user.default_organization)
    end
  end
end
