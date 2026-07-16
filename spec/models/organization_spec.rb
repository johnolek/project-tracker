require "rails_helper"

RSpec.describe Organization, type: :model do
  subject { build(:organization) }

  it { is_expected.to validate_presence_of(:name) }

  it { is_expected.to have_many(:memberships).dependent(:destroy) }
  it { is_expected.to have_many(:users).through(:memberships) }
  it { is_expected.to have_many(:projects).dependent(:destroy) }
  it { is_expected.to have_many(:statuses).dependent(:destroy) }

  describe "default statuses" do
    let(:organization) { create(:organization) }

    it "are seeded on creation" do
      seeded = organization.statuses.ordered.map { |status| [ status.name, status.category, status.position ] }
      expect(seeded).to eq([
        [ "New", "open", 1 ],
        [ "In Progress", "in_progress", 2 ],
        [ "Completed", "done", 3 ]
      ])
    end
  end

  describe "#default_status" do
    let(:organization) { create(:organization) }

    it "returns the first open-category status" do
      expect(organization.default_status.name).to eq("New")
      expect(organization.default_status.category).to eq("open")
    end
  end
end
