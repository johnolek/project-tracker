require "rails_helper"

RSpec.describe Credential, type: :model do
  subject { create(:credential) }

  it { is_expected.to belong_to(:user) }

  it { is_expected.to validate_presence_of(:external_id) }
  it { is_expected.to validate_presence_of(:public_key) }

  it "requires a unique external_id" do
    existing = create(:credential)
    expect(build(:credential, external_id: existing.external_id)).not_to be_valid
  end
  it { is_expected.to validate_numericality_of(:sign_count).only_integer.is_greater_than_or_equal_to(0) }
end
