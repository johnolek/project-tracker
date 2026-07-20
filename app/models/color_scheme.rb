# The built-in color schemes a user can pick in Settings → Appearance
# (PROJ-32). Every scheme here was contrast-verified to WCAG AA in BOTH light
# and dark modes against the built CSS values (see the scheme blocks in
# application.sass.scss, which must stay in step with these seeds). "southwest"
# is the compiled Bulma default — its CSS emits no override block.
module ColorScheme
  Scheme = Data.define(:key, :label, :description, :swatches, :theme_color_light, :theme_color_dark)

  BUILT_IN = [
    Scheme.new(
      key: "southwest",
      label: "Southwest",
      description: "Warm terracotta and sand — the original.",
      swatches: [ "hsl(14, 58%, 40%)", "hsl(178, 55%, 27%)", "hsl(42, 92%, 50%)" ],
      theme_color_light: "#a1462b",
      theme_color_dark: "#1d1711"
    ),
    Scheme.new(
      key: "mesa-verde",
      label: "Mesa Verde",
      description: "Deep greens with a cool sage wash.",
      swatches: [ "hsl(150, 45%, 30%)", "hsl(200, 50%, 32%)", "hsl(44, 90%, 50%)" ],
      theme_color_light: "#2a6f4d",
      theme_color_dark: "#141a16"
    ),
    Scheme.new(
      key: "gulf",
      label: "Gulf",
      description: "Ocean blues over a cool grey shore.",
      swatches: [ "hsl(205, 60%, 38%)", "hsl(180, 55%, 28%)", "hsl(42, 92%, 50%)" ],
      theme_color_light: "#276b9b",
      theme_color_dark: "#12171c"
    ),
    Scheme.new(
      key: "adobe-dusk",
      label: "Adobe Dusk",
      description: "Violet twilight on neutral slate.",
      swatches: [ "hsl(262, 45%, 45%)", "hsl(210, 45%, 35%)", "hsl(42, 92%, 50%)" ],
      theme_color_light: "#653fa6",
      theme_color_dark: "#161519"
    )
  ].freeze

  KEYS = BUILT_IN.map(&:key).freeze
  DEFAULT = "southwest"

  # @param key [String]
  # @return [ColorScheme::Scheme]
  def self.fetch(key)
    BUILT_IN.find { |scheme| scheme.key == key } || BUILT_IN.first
  end
end
