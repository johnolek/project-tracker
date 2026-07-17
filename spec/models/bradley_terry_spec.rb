require "rails_helper"

RSpec.describe BradleyTerry do
  # Lightweight stand-in so the solver specs never touch the database; the solver
  # only reads #item_a_id, #item_b_id and #outcome.
  Pair = Struct.new(:item_a_id, :item_b_id, :outcome)

  def a_wins(a, b) = Pair.new(a, b, "a_wins")
  def b_wins(a, b) = Pair.new(a, b, "b_wins")
  def draw(a, b) = Pair.new(a, b, "draw")

  describe ".fit" do
    it "returns an empty hash for no comparisons" do
      expect(described_class.fit(comparisons: [])).to eq({})
    end

    it "ranks a consistent winner above the loser" do
      result = described_class.fit(comparisons: [ a_wins(1, 2), a_wins(1, 2) ])

      expect(result[1]).to be > result[2]
    end

    it "treats winner orientation symmetrically (b_wins mirrors a_wins)" do
      forward = described_class.fit(comparisons: [ a_wins(1, 2) ])
      reversed = described_class.fit(comparisons: [ b_wins(2, 1) ])

      expect(forward[1]).to be_within(1e-9).of(reversed[1])
      expect(forward[2]).to be_within(1e-9).of(reversed[2])
    end

    it "preserves transitivity: A beats B, B beats C implies A > B > C" do
      result = described_class.fit(comparisons: [ a_wins(1, 2), a_wins(2, 3) ])

      expect(result[1]).to be > result[2]
      expect(result[2]).to be > result[3]
    end

    it "leaves two items that only ever draw at equal strength" do
      result = described_class.fit(comparisons: [ draw(1, 2), draw(1, 2) ])

      expect(result[1]).to be_within(1e-9).of(result[2])
    end

    it "pulls a drawn pair toward equal relative to a decisive pair" do
      decisive = described_class.fit(comparisons: [ a_wins(1, 2) ])
      drawn = described_class.fit(comparisons: [ draw(1, 2) ])

      expect((drawn[1] - drawn[2]).abs).to be < (decisive[1] - decisive[2]).abs
    end

    it "keeps disconnected comparison components finite and separately ranked" do
      result = described_class.fit(comparisons: [ a_wins(1, 2), a_wins(3, 4) ])

      expect(result.values).to all(be_finite)
      expect(result[1]).to be > result[2]
      expect(result[3]).to be > result[4]
    end

    it "keeps an undefeated item finite thanks to regularization" do
      result = described_class.fit(comparisons: Array.new(5) { a_wins(1, 2) })

      expect(result[1]).to be_finite
      expect(result[1]).to be > result[2]
    end

    it "centers the log-strengths at mean 0" do
      result = described_class.fit(comparisons: [ a_wins(1, 2), a_wins(2, 3) ])

      expect(result.values.sum).to be_within(1e-9).of(0.0)
    end

    it "is deterministic across runs" do
      comparisons = [ a_wins(1, 2), draw(2, 3), b_wins(1, 3) ]

      expect(described_class.fit(comparisons: comparisons)).to eq(described_class.fit(comparisons: comparisons))
    end

    it "orders result keys by item id" do
      result = described_class.fit(comparisons: [ a_wins(3, 1), a_wins(1, 2) ])

      expect(result.keys).to eq([ 1, 2, 3 ])
    end

    it "ranks a stronger win record above a weaker one" do
      # 1 beats 2 three times; 2 beats 3 once. 1 should top the ranking.
      result = described_class.fit(comparisons: [ a_wins(1, 2), a_wins(1, 2), a_wins(1, 2), a_wins(2, 3) ])

      expect(result.max_by { |_id, strength| strength }.first).to eq(1)
      expect(result.min_by { |_id, strength| strength }.first).to eq(3)
    end
  end
end
