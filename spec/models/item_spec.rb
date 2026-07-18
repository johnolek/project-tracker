require "rails_helper"

RSpec.describe Item, type: :model do
  subject { build(:item) }

  it { is_expected.to belong_to(:project) }
  it { is_expected.to have_many(:comments).dependent(:destroy) }
  it { is_expected.to have_many(:comparisons_as_item_a).class_name("Comparison").dependent(:destroy) }
  it { is_expected.to have_many(:comparisons_as_item_b).class_name("Comparison").dependent(:destroy) }
  it { is_expected.to have_many(:item_tags).dependent(:destroy) }
  it { is_expected.to have_many(:tags).through(:item_tags) }

  it "belongs to a status" do
    expect(described_class.reflect_on_association(:status).macro).to eq(:belongs_to)
  end

  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:strength) }
  it { is_expected.to validate_numericality_of(:strength) }
  describe "item_type must be one of the organization's configured types" do
    let(:project) { create(:project) }

    it "accepts a configured type name (case-insensitively)" do
      expect(build(:item, project: project, item_type: "BUG")).to be_valid
    end

    it "rejects a type the organization hasn't configured" do
      item = build(:item, project: project, item_type: "nonsense")
      expect(item).not_to be_valid
      expect(item.errors[:item_type]).to be_present
    end
  end
  it { is_expected.to validate_numericality_of(:points).only_integer.is_greater_than(0).allow_nil }

  describe "default status assignment" do
    let(:project) { create(:project) }

    it "assigns the organization's first open status when none is given" do
      item = project.items.create!(title: "A task")
      expect(item.status).to eq(project.organization.default_status)
      expect(item.status.name).to eq("New")
    end

    it "keeps an explicitly assigned status" do
      completed = project.organization.statuses.find_by(category: "done")
      item = project.items.create!(title: "A task", status: completed)
      expect(item.status).to eq(completed)
    end
  end

  describe "tags" do
    let(:item) { create(:item) }
    let(:organization) { item.project.organization }

    it "creates tags from a comma-separated string on save" do
      item.update!(tag_names: "backend, urgent")

      expect(item.reload.tag_names).to eq(%w[backend urgent])
      expect(Tag.where(organization: organization).pluck(:name)).to contain_exactly("backend", "urgent")
    end

    it "creates tags from an array of names on save" do
      item.update!(tag_names: [ "backend", "urgent" ])

      expect(item.reload.tag_names).to eq(%w[backend urgent])
    end

    it "normalizes names, dropping blanks and case-insensitive duplicates" do
      item.update!(tag_names: " Backend , backend, , urgent ")

      expect(item.reload.tag_names).to contain_exactly("Backend", "urgent")
    end

    it "reuses an existing tag case-insensitively without creating a duplicate" do
      existing = create(:tag, organization: organization, name: "bug")
      item.update!(tag_names: "Bug")

      expect(item.tags).to contain_exactly(existing)
      expect(Tag.where(organization: organization).count).to eq(1)
    end

    it "replaces the full tag set on reassignment" do
      item.update!(tag_names: "one, two")
      item.update!(tag_names: "two, three")

      expect(item.reload.tag_names).to contain_exactly("two", "three")
    end

    it "leaves tags alone when tag_names is never assigned" do
      item.update!(tag_names: "keep")
      Item.find(item.id).update!(title: "Renamed")

      expect(item.reload.tag_names).to eq([ "keep" ])
    end
  end

  describe "numbering and key" do
    let(:project) { create(:project, name: "Project Tracker") }

    it "assigns sequential per-project numbers on create" do
      first = project.items.create!(title: "First")
      second = project.items.create!(title: "Second")

      expect(first.number).to eq(1)
      expect(second.number).to eq(2)
    end

    it "scopes the sequence to the project" do
      other_project = create(:project)
      project.items.create!(title: "First here")

      expect(other_project.items.create!(title: "First there").number).to eq(1)
    end

    it "never reuses a number after deletion" do
      project.items.create!(title: "First")
      project.items.create!(title: "Second").destroy!

      expect(project.items.create!(title: "Third").number).to eq(3)
    end

    it "composes the key from the project slug and number" do
      item = project.items.create!(title: "First")

      expect(item.key).to eq("PROJ-1")
      expect(item.board_payload[:key]).to eq("PROJ-1")
      expect(item.detail_payload[:key]).to eq("PROJ-1")
    end
  end

  describe "column defaults" do
    it "starts at neutral Bradley-Terry strength and feature type" do
      item = Item.new
      expect(item.strength).to eq(0.0)
      expect(item.item_type).to eq("feature")
    end
  end

  describe "#provenance" do
    it "derives from source and the AI sign-off timestamp" do
      expect(Item.new(source: "api").provenance).to eq("ai_created")
      expect(Item.new(source: "web").provenance).to eq("user_created")
      expect(Item.new(source: "web", ai_reviewed_at: Time.current).provenance).to eq("ai_reviewed")
    end

    it "rejects unknown sources" do
      expect(Item.new(source: "carrier-pigeon")).not_to be_valid
    end
  end

  describe "legacy item types" do
    it "stores task and enhancement as feature" do
      expect(Item.new(item_type: "task").item_type).to eq("feature")
      expect(Item.new(item_type: "enhancement").item_type).to eq("feature")
    end

    it "leaves current types and unknown values untouched" do
      expect(Item.new(item_type: "bug").item_type).to eq("bug")
      expect(Item.new(item_type: "bogus")).not_to be_valid
    end
  end

  describe "parent items" do
    let(:project) { create(:project) }
    let(:root) { create(:item, project: project) }

    it "groups items under a parent to arbitrary depth" do
      child = create(:item, project: project, parent: root)
      grandchild = create(:item, project: project, parent: child)

      expect(root.children).to eq([ child ])
      expect(grandchild.ancestors).to eq([ child, root ])
      expect(root.descendant_ids).to match_array([ child.id, grandchild.id ])
    end

    it "orders children by number" do
      later = create(:item, project: project, parent: root)
      create(:item, project: project)
      earlier = create(:item, project: project)
      earlier.update!(parent: root)

      expect(root.children).to eq([ later, earlier ].sort_by(&:number))
    end

    it "rejects a parent from another project" do
      foreign = create(:item)
      item = build(:item, project: project, parent: foreign)

      expect(item).not_to be_valid
      expect(item.errors[:parent]).to include("must belong to the same project")
    end

    it "rejects the item itself and its descendants as parent" do
      child = create(:item, project: project, parent: root)
      grandchild = create(:item, project: project, parent: child)

      root.parent = root
      expect(root).not_to be_valid

      root.parent = grandchild
      expect(root).not_to be_valid
      expect(root.errors[:parent]).to include("can't be the item itself or one of its sub-items")
    end

    it "excludes the item and its descendants from parent_candidates" do
      child = create(:item, project: project, parent: root)
      sibling = create(:item, project: project)

      expect(root.parent_candidates).to contain_exactly(sibling)
      expect(child.parent_candidates).to contain_exactly(root, sibling)
    end

    it "promotes children to roots when the parent is destroyed" do
      child = create(:item, project: project, parent: root)

      root.destroy!

      expect(child.reload.parent).to be_nil
    end
  end
end
