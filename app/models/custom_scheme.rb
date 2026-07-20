# A user-authored color scheme (PROJ-32): seven hex colors — a surface tint
# (hue/saturation only; the standard light/dark lightness ramps do the rest)
# and the six Bulma semantic colors. Rendered as inline CSS variables on
# <html>, which beat every stylesheet block, in both modes. Contrast here is
# the user's choice: the appearance editor warns on AA failures client-side
# (theme_contrast.js) but saving is never blocked.
module CustomScheme
  KEYS = %w[tint primary link info success warning danger].freeze
  HEX = /\A#\h{6}\z/

  # Southwest's seeds as hexes — what the editor starts from.
  DEFAULTS = {
    "tint" => "#a3825c",
    "primary" => "#a1462b",
    "link" => "#8f3c1e",
    "info" => "#1f6b68",
    "success" => "#4c633b",
    "warning" => "#f5ae0a",
    "danger" => "#9d2925"
  }.freeze

  # @param colors [Object]
  # @return [Boolean] a Hash of known keys mapping to 6-digit hex colors
  def self.valid?(colors)
    colors.is_a?(Hash) &&
      colors.keys.sort == KEYS.sort &&
      colors.values.all? { |value| value.is_a?(String) && value.match?(HEX) }
  end

  # The inline style applying the scheme: the tint contributes the scheme
  # hue/saturation, each semantic color its full h/s/l seed. Mirrors
  # buildCustomVariables in theme_contrast.js.
  #
  # @param colors [Hash{String => String}]
  # @return [String]
  def self.css_variables(colors)
    tint_h, tint_s, = hsl(colors.fetch("tint"))
    variables = [ "--bulma-scheme-h: #{tint_h}", "--bulma-scheme-s: #{tint_s}%" ]

    (KEYS - [ "tint" ]).each do |key|
      h, s, l = hsl(colors.fetch(key))
      variables << "--bulma-#{key}-h: #{h}deg"
      variables << "--bulma-#{key}-s: #{s}%"
      variables << "--bulma-#{key}-l: #{l}%"
    end

    variables.join("; ")
  end

  # Browser theme-color metas for a custom scheme: the primary seed in light,
  # the tint at the dark background lightness in dark.
  #
  # @param colors [Hash{String => String}]
  # @return [Array(String, String)] light and dark hex
  def self.theme_colors(colors)
    tint_h, tint_s, = hsl(colors.fetch("tint"))
    [ colors.fetch("primary"), hex(tint_h, tint_s, 9) ]
  end

  # @param value [String] "#rrggbb"
  # @return [Array(Integer, Integer, Integer)] h (0-359), s and l (0-100)
  def self.hsl(value)
    r, g, b = value.delete_prefix("#").scan(/../).map { |pair| pair.to_i(16) / 255.0 }
    max, min = [ r, g, b ].max, [ r, g, b ].min
    l = (max + min) / 2.0
    return [ 0, 0, (l * 100).round ] if max == min

    delta = max - min
    s = l > 0.5 ? delta / (2.0 - max - min) : delta / (max + min)
    h = case max
        when r then ((g - b) / delta) % 6
        when g then (b - r) / delta + 2
        else (r - g) / delta + 4
        end
    [ (h * 60).round % 360, (s * 100).round, (l * 100).round ]
  end

  # @return [String] "#rrggbb" for the given HSL components
  def self.hex(h, s, l)
    s /= 100.0
    l /= 100.0
    chroma = (1 - (2 * l - 1).abs) * s
    x = chroma * (1 - ((h / 60.0) % 2 - 1).abs)
    m = l - chroma / 2
    r, g, b = case h
              when 0...60 then [ chroma, x, 0 ]
              when 60...120 then [ x, chroma, 0 ]
              when 120...180 then [ 0, chroma, x ]
              when 180...240 then [ 0, x, chroma ]
              when 240...300 then [ x, 0, chroma ]
              else [ chroma, 0, x ]
              end
    format("#%02x%02x%02x", *[ r, g, b ].map { |channel| ((channel + m) * 255).round })
  end
end
