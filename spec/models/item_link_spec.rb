require "rails_helper"

RSpec.describe ItemLink, type: :model do
  subject { build(:item_link) }

  it { is_expected.to belong_to(:source).class_name("Item") }
  it { is_expected.to belong_to(:target).class_name("Item") }
  it { is_expected.to validate_inclusion_of(:kind).in_array(ItemLink::KINDS) }

  it "links two items in the same project" do
    expect(build(:item_link)).to be_valid
  end

  it "links items across projects within one organization" do
    organization = create(:organization)
    source = create(:item, project: create(:project, organization: organization))
    target = create(:item, project: create(:project, organization: organization))

    expect(build(:item_link, source: source, target: target)).to be_valid
  end

  it "rejects links across organizations" do
    link = build(:item_link, source: create(:item), target: create(:item))

    expect(link).not_to be_valid
    expect(link.errors[:target]).to include("must belong to the same organization")
  end

  it "rejects linking an item to itself" do
    item = create(:item)
    link = build(:item_link, source: item, target: item)

    expect(link).not_to be_valid
    expect(link.errors[:target]).to include("can't be the item itself")
  end

  it "rejects an exact duplicate link" do
    existing = create(:item_link)
    duplicate = build(:item_link, source: existing.source, target: existing.target, kind: existing.kind)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:target_id]).to include("is already linked")
  end

  it "rejects a reversed relates_to duplicate but allows mutual blocks" do
    related = create(:item_link, kind: "relates_to")
    reversed = build(:item_link, source: related.target, target: related.source, kind: "relates_to")
    expect(reversed).not_to be_valid

    blocking = create(:item_link, kind: "blocks")
    deadlock = build(:item_link, source: blocking.target, target: blocking.source, kind: "blocks")
    expect(deadlock).to be_valid
  end

  it "is destroyed with either endpoint" do
    link = create(:item_link)
    other = create(:item_link)

    link.source.destroy!
    other.target.destroy!

    expect(ItemLink.exists?(link.id)).to be(false)
    expect(ItemLink.exists?(other.id)).to be(false)
  end

  describe "Item#grouped_links" do
    it "buckets links from the item's point of view" do
      project = create(:project)
      item = create(:item, project: project)
      blocked = create(:item, project: project)
      blocker = create(:item, project: project)
      related = create(:item, project: project)

      blocks_link = create(:item_link, source: item, target: blocked, kind: "blocks")
      blocked_by_link = create(:item_link, source: blocker, target: item, kind: "blocks")
      related_link = create(:item_link, source: related, target: item, kind: "relates_to")

      expect(item.grouped_links).to eq(
        blocks: [ [ blocks_link, blocked ] ],
        blocked_by: [ [ blocked_by_link, blocker ] ],
        relates_to: [ [ related_link, related ] ]
      )
    end
  end
end
