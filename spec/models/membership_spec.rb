require "rails_helper"

RSpec.describe Membership, type: :model do
  subject { build(:membership) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:organization) }

  it { is_expected.to validate_presence_of(:role) }

  it "is unique per user and organization" do
    existing = create(:membership)
    duplicate = build(:membership, user: existing.user, organization: existing.organization)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:user_id]).to be_present
  end
end
