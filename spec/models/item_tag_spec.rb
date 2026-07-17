require "rails_helper"

RSpec.describe ItemTag, type: :model do
  it { is_expected.to belong_to(:item) }
  it { is_expected.to belong_to(:tag) }

  it "rejects the same tag twice on one item" do
    item = create(:item)
    tag = create(:tag, organization: item.project.organization)
    ItemTag.create!(item: item, tag: tag)
    duplicate = ItemTag.new(item: item, tag: tag)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:tag_id]).to be_present
  end

  it "allows the same tag on different items" do
    item = create(:item)
    other_item = create(:item, project: item.project)
    tag = create(:tag, organization: item.project.organization)
    ItemTag.create!(item: item, tag: tag)

    expect(ItemTag.new(item: other_item, tag: tag)).to be_valid
  end
end
