require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#tag_color_class" do
    # Known djb2(seed 5381, *33 over lowercased UTF-8 bytes) mod 8 mappings.
    # These MUST stay in lockstep with app/javascript/tag_color.js so a tag
    # gets the same color in ERB and on the Svelte board.
    {
      "bug" => "tag-color-3",
      "backend" => "tag-color-5",
      "urgent" => "tag-color-2",
      "design" => "tag-color-7",
      "docs" => "tag-color-6",
      "database" => "tag-color-2"
    }.each do |name, expected|
      it "maps #{name.inspect} to #{expected}" do
        expect(helper.tag_color_class(name: name)).to eq(expected)
      end
    end

    it "is case-insensitive" do
      expect(helper.tag_color_class(name: "Backend"))
        .to eq(helper.tag_color_class(name: "backend"))
      expect(helper.tag_color_class(name: "BACKEND"))
        .to eq(helper.tag_color_class(name: "backend"))
    end

    it "always lands in one of the eight palette buckets" do
      %w[a alpha beta gamma delta epsilon zeta eta theta iota kappa lambda].each do |name|
        expect(helper.tag_color_class(name: name)).to match(/\Atag-color-[0-7]\z/)
      end
    end
  end

  describe "#item_type_tag" do
    it "colors the chip inline from the item's resolved type color" do
      html = helper.item_type_tag(double(item_type: "bug", item_type_color: "#9D2925"))
      expect(html).to include('class="item-type-tag"')
      expect(html).to include("background-color: #9D2925")
      expect(html).to include("color: #ffffff")
      expect(html).to include(">bug</span>")
    end

    it "renders a plain chip when the type has no resolved color" do
      html = helper.item_type_tag(double(item_type: "bug", item_type_color: nil))
      expect(html).to eq('<span class="item-type-tag">bug</span>')
    end
  end
end
