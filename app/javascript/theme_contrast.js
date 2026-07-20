// Custom-scheme support for the appearance editor (PROJ-32): hex→HSL, the
// inline variable set (mirroring CustomScheme.css_variables server-side), and
// WCAG AA contrast warnings. The derived lightness constants come from the
// built Bulma CSS: invert lightness per semantic color, the per-mode
// "on-scheme" text lightness lifts, and the light/dark background ramp
// (scheme-main 96%/9%). Warnings inform — saving is never blocked.

export const SEMANTIC_KEYS = ["primary", "link", "info", "success", "warning", "danger"]

const INVERT_L = { primary: 100, link: 99, info: 100, success: 100, warning: 10, danger: 98 }
const ON_SCHEME_L = {
  primary: { light: 35, dark: 60 },
  link: { light: 34, dark: 59 },
  info: { light: 22, dark: 42 },
  success: { light: 31, dark: 46 },
  warning: { light: 25, dark: 50 },
  danger: { light: 38, dark: 63 },
}
const BACKGROUND_L = { light: 96, dark: 9 }
const TEXT_WEAK_L = { light: 40, dark: 53 }

export function hexToHsl(hex) {
  const [r, g, b] = [1, 3, 5].map((offset) => parseInt(hex.slice(offset, offset + 2), 16) / 255)
  const max = Math.max(r, g, b)
  const min = Math.min(r, g, b)
  const l = (max + min) / 2
  if (max === min) return { h: 0, s: 0, l: Math.round(l * 100) }

  const delta = max - min
  const s = l > 0.5 ? delta / (2 - max - min) : delta / (max + min)
  let h
  if (max === r) h = ((g - b) / delta) % 6
  else if (max === g) h = (b - r) / delta + 2
  else h = (r - g) / delta + 4
  return { h: ((Math.round(h * 60) % 360) + 360) % 360, s: Math.round(s * 100), l: Math.round(l * 100) }
}

// The inline style variables for a custom color set — one string, mirroring
// CustomScheme.css_variables exactly so live preview matches the next load.
export function buildCustomVariables(colors) {
  const tint = hexToHsl(colors.tint)
  const variables = [`--bulma-scheme-h: ${tint.h}`, `--bulma-scheme-s: ${tint.s}%`]
  for (const key of SEMANTIC_KEYS) {
    const { h, s, l } = hexToHsl(colors[key])
    variables.push(`--bulma-${key}-h: ${h}deg`, `--bulma-${key}-s: ${s}%`, `--bulma-${key}-l: ${l}%`)
  }
  return variables.join("; ")
}

function relativeLuminance(h, s, l) {
  const [r, g, b] = hslToRgb(h, s, l)
  const channel = (value) => (value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4)
  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
}

function hslToRgb(h, s, l) {
  s /= 100
  l /= 100
  const chroma = (1 - Math.abs(2 * l - 1)) * s
  const x = chroma * (1 - Math.abs(((h / 60) % 2) - 1))
  const m = l - chroma / 2
  const sextant = Math.floor(((h % 360) + 360) % 360 / 60)
  const [r, g, b] = [
    [chroma, x, 0], [x, chroma, 0], [0, chroma, x],
    [0, x, chroma], [x, 0, chroma], [chroma, 0, x],
  ][sextant]
  return [r + m, g + m, b + m]
}

function contrast(first, second) {
  const one = relativeLuminance(first.h, first.s, first.l)
  const two = relativeLuminance(second.h, second.s, second.l)
  const [hi, lo] = one > two ? [one, two] : [two, one]
  return (hi + 0.05) / (lo + 0.05)
}

const LABELS = {
  primary: "Primary", link: "Link", info: "Info",
  success: "Success", warning: "Warning", danger: "Danger",
}

// AA warnings for a custom color set, one human sentence each. The checks
// mirror the ones the built-in schemes were verified against: button text on
// each color, each color as text on the light and dark backgrounds (with
// Bulma's per-mode lightness lifts applied), primary as a non-text accent,
// and the tint's weak-text ramp.
export function contrastWarnings(colors) {
  const warnings = []
  const tint = hexToHsl(colors.tint)
  const backgrounds = {
    light: { h: tint.h, s: tint.s, l: BACKGROUND_L.light },
    dark: { h: tint.h, s: tint.s, l: BACKGROUND_L.dark },
  }
  const flag = (ratio, minimum, message) => {
    if (ratio < minimum) warnings.push(`${message} (${ratio.toFixed(1)}:1, needs ${minimum}:1).`)
  }

  for (const key of SEMANTIC_KEYS) {
    const seed = hexToHsl(colors[key])
    flag(
      contrast(seed, { ...seed, l: INVERT_L[key] }), 4.5,
      `${LABELS[key]} is hard to read as button text`
    )
    for (const mode of ["light", "dark"]) {
      flag(
        contrast({ ...seed, l: ON_SCHEME_L[key][mode] }, backgrounds[mode]), 4.5,
        `${LABELS[key]} text is hard to read on the ${mode} background`
      )
    }
  }

  // Inline variables beat every stylesheet block, so a custom seed keeps its
  // lightness in dark mode too (no built-in dark lift applies).
  const primary = hexToHsl(colors.primary)
  for (const mode of ["light", "dark"]) {
    flag(
      contrast(primary, backgrounds[mode]), 3,
      `Primary blends into the ${mode} background as an accent`
    )
    flag(
      contrast({ h: tint.h, s: tint.s, l: TEXT_WEAK_L[mode] }, backgrounds[mode]), 4.5,
      `Muted text is hard to read on the ${mode} background with this tint`
    )
  }

  return warnings
}
