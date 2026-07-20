require "rails_helper"

RSpec.describe Status, type: :model do
  subject { build(:status) }

  it { is_expected.to belong_to(:organization) }
  it { is_expected.to have_many(:items).dependent(:restrict_with_error) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:position) }
  it { is_expected.to validate_numericality_of(:position).only_integer }
  it { is_expected.to validate_inclusion_of(:category).in_array(Status::CATEGORIES) }

  describe "uniqueness within an organization" do
    let(:organization) { create(:organization) }

    it "rejects a duplicate name case-insensitively" do
      create(:status, organization: organization, name: "Blocked", position: 201)
      dupe = build(:status, organization: organization, name: "blocked", position: 202)

      expect(dupe).not_to be_valid
      expect(dupe.errors[:name]).to be_present
    end

    it "rejects a duplicate position" do
      create(:status, organization: organization, name: "One", position: 203)
      dupe = build(:status, organization: organization, name: "Two", position: 203)

      expect(dupe).not_to be_valid
      expect(dupe.errors[:position]).to be_present
    end

    it "allows the same name in another organization" do
      create(:status, organization: organization, name: "Blocked", position: 201)

      expect(build(:status, name: "Blocked", position: 201)).to be_valid
    end
  end
end
