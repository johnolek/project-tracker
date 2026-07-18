require "rails_helper"

RSpec.describe ItemType, type: :model do
  describe "validations" do
    subject { build(:item_type) }

    it { is_expected.to belong_to(:organization) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:position) }

    it "requires a name unique per organization (case-insensitive)" do
      org = create(:organization)
      create(:item_type, organization: org, name: "Chore")
      expect(build(:item_type, organization: org, name: "chore")).not_to be_valid
    end

    it "allows the same name in a different organization" do
      create(:item_type, organization: create(:organization), name: "chore")
      expect(build(:item_type, organization: create(:organization), name: "chore")).to be_valid
    end

    it "rejects a non-hex color" do
      expect(build(:item_type, color: "reddish")).not_to be_valid
    end

    it "accepts #rgb and #rrggbb colors" do
      expect(build(:item_type, color: "#abc")).to be_valid
      expect(build(:item_type, color: "#aabbcc")).to be_valid
    end
  end

  describe "default color assignment" do
    it "assigns an unused palette color when none is given" do
      org = create(:organization) # after_create seeds three types on PALETTE[0..2]
      type = org.item_types.create!(name: "custom", position: 99)

      expect(type.color).to match(/\A#\h{6}\z/i)
      expect(ItemType::PALETTE.first(3)).not_to include(type.color.upcase)
    end

    it "keeps an explicitly provided color" do
      type = build(:item_type, color: "#123456")
      type.valid?
      expect(type.color).to eq("#123456")
    end
  end

  describe "rename cascade" do
    it "renames the denormalized item_type on items in the org" do
      org = create(:organization)
      project = create(:project, organization: org)
      item = create(:item, project: project, item_type: "feature")

      org.item_types.find_by!(name: "feature").update!(name: "story")

      expect(item.reload.item_type).to eq("story")
    end
  end

  describe "delete guard" do
    it "refuses to destroy a type still used by an item" do
      org = create(:organization)
      project = create(:project, organization: org)
      create(:item, project: project, item_type: "bug")
      type = org.item_types.find_by!(name: "bug")

      expect(type.destroy).to be_falsey
      expect(org.item_types.exists?(id: type.id)).to be(true)
    end

    it "destroys a type no item uses" do
      org = create(:organization)
      type = org.item_types.create!(name: "unused", color: "#123456", position: 50)
      expect(type.destroy).to be_truthy
    end
  end

  describe ".readable_text_color" do
    it "returns white on dark backgrounds and near-black on light ones" do
      expect(described_class.readable_text_color("#000000")).to eq("#ffffff")
      expect(described_class.readable_text_color("#ffffff")).to eq("#1a1a1a")
      expect(described_class.readable_text_color("#F5AE0A")).to eq("#1a1a1a")
    end

    it "returns nil for a blank color" do
      expect(described_class.readable_text_color(nil)).to be_nil
    end
  end
end
