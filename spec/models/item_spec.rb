require "rails_helper"

RSpec.describe Item, type: :model do
  subject { build(:item) }

  it { is_expected.to belong_to(:project) }
  it { is_expected.to have_many(:comments).dependent(:destroy) }

  it "belongs to a status" do
    expect(described_class.reflect_on_association(:status).macro).to eq(:belongs_to)
  end

  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:elo_rating) }
  it { is_expected.to validate_numericality_of(:elo_rating).only_integer }
  it { is_expected.to validate_inclusion_of(:item_type).in_array(Item::ITEM_TYPES) }
  it { is_expected.to validate_inclusion_of(:source).in_array(Item::SOURCES) }
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

  describe "column defaults" do
    it "starts with an elo rating of 1000 and internal source" do
      item = Item.new
      expect(item.elo_rating).to eq(1000)
      expect(item.source).to eq("internal")
      expect(item.item_type).to eq("task")
    end
  end
end
