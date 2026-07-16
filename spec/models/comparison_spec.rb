require "rails_helper"

RSpec.describe Comparison, type: :model do
  it { is_expected.to belong_to(:item_a).class_name("Item") }
  it { is_expected.to belong_to(:item_b).class_name("Item") }
  it { is_expected.to belong_to(:user) }

  it { is_expected.to validate_inclusion_of(:outcome).in_array(Comparison::OUTCOMES) }

  it "has a valid factory" do
    expect(build(:comparison)).to be_valid
  end

  it "accepts a draw outcome" do
    expect(build(:comparison, outcome: "draw")).to be_valid
  end

  it "rejects a comparison of an item with itself" do
    project = create(:project)
    item = create(:item, project: project)
    comparison = build(:comparison, item_a: item, item_b: item, user: create(:user))

    expect(comparison).not_to be_valid
    expect(comparison.errors[:item_b]).to be_present
  end

  it "rejects items from different organizations" do
    comparison = build(:comparison, item_a: create(:item), item_b: create(:item), user: create(:user))

    expect(comparison).not_to be_valid
    expect(comparison.errors[:item_b]).to be_present
  end

  it "allows the same pair to be compared more than once" do
    first = create(:comparison)
    duplicate = build(:comparison, item_a: first.item_a, item_b: first.item_b, user: first.user)

    expect(duplicate).to be_valid
  end

  describe "#winner, #loser, #draw?" do
    let(:comparison) { build(:comparison) }

    it "derives the winner and loser when item A wins" do
      comparison.outcome = "a_wins"
      expect(comparison.winner).to eq(comparison.item_a)
      expect(comparison.loser).to eq(comparison.item_b)
      expect(comparison).not_to be_draw
    end

    it "derives the winner and loser when item B wins" do
      comparison.outcome = "b_wins"
      expect(comparison.winner).to eq(comparison.item_b)
      expect(comparison.loser).to eq(comparison.item_a)
      expect(comparison).not_to be_draw
    end

    it "returns nil for both on a draw" do
      comparison.outcome = "draw"
      expect(comparison.winner).to be_nil
      expect(comparison.loser).to be_nil
      expect(comparison).to be_draw
    end
  end
end
