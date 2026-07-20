require "rails_helper"

RSpec.describe CustomScheme do
  describe ".valid?" do
    it "accepts the defaults" do
      expect(described_class.valid?(described_class::DEFAULTS)).to be(true)
    end

    it "rejects missing keys, unknown keys, and non-hex values" do
      expect(described_class.valid?(described_class::DEFAULTS.except("tint"))).to be(false)
      expect(described_class.valid?(described_class::DEFAULTS.merge("sparkle" => "#123456"))).to be(false)
      expect(described_class.valid?(described_class::DEFAULTS.merge("primary" => "red"))).to be(false)
      expect(described_class.valid?(nil)).to be(false)
    end
  end

  describe ".hsl" do
    it "round-trips the Southwest primary seed" do
      expect(described_class.hsl("#a1462b")).to eq([ 14, 58, 40 ])
    end

    it "handles greys" do
      expect(described_class.hsl("#808080")).to eq([ 0, 0, 50 ])
    end
  end

  describe ".css_variables" do
    it "emits the scheme tint as hue/saturation and full seeds for each semantic color" do
      style = described_class.css_variables(described_class::DEFAULTS)

      expect(style).to include("--bulma-scheme-h: 32; --bulma-scheme-s: 28%")
      expect(style).to include("--bulma-primary-h: 14deg; --bulma-primary-s: 58%; --bulma-primary-l: 40%")
      expect(style).to include("--bulma-danger-h: 2deg; --bulma-danger-s: 62%; --bulma-danger-l: 38%")
      expect(style).not_to include("--bulma-tint")
    end
  end

  describe ".theme_colors" do
    it "uses the primary seed in light and the tint's dark background in dark" do
      expect(described_class.theme_colors(described_class::DEFAULTS)).to eq([ "#a1462b", "#1d1711" ])
    end
  end
end
