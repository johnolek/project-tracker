require "rails_helper"

RSpec.describe Tag, type: :model do
  it { is_expected.to belong_to(:organization) }
  it { is_expected.to have_many(:item_tags).dependent(:destroy) }
  it { is_expected.to have_many(:items).through(:item_tags) }
  it { is_expected.to validate_presence_of(:name) }

  it "has a valid factory" do
    expect(build(:tag)).to be_valid
  end

  it "rejects a name differing only by case within the same organization" do
    existing = create(:tag, name: "bug")
    duplicate = build(:tag, organization: existing.organization, name: "Bug")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it "allows the same name in a different organization" do
    create(:tag, name: "bug")

    expect(build(:tag, name: "bug")).to be_valid
  end
end
