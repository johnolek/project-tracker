import { describe, it, expect } from "vitest"
import { hexToHsl, buildCustomVariables, contrastWarnings } from "../../app/javascript/theme_contrast"

// Southwest's seeds as hexes (CustomScheme::DEFAULTS server-side).
const SOUTHWEST = {
  tint: "#a3825c",
  primary: "#a1462b",
  link: "#8f3c1e",
  info: "#1f6b68",
  success: "#4c633b",
  warning: "#f5ae0a",
  danger: "#9d2925",
}

describe("hexToHsl", () => {
  it("round-trips the Southwest primary seed", () => {
    expect(hexToHsl("#a1462b")).toEqual({ h: 14, s: 58, l: 40 })
  })

  it("handles greys", () => {
    expect(hexToHsl("#808080")).toEqual({ h: 0, s: 0, l: 50 })
  })
})

describe("buildCustomVariables", () => {
  it("mirrors CustomScheme.css_variables for the Southwest defaults", () => {
    expect(buildCustomVariables(SOUTHWEST)).toBe(
      "--bulma-scheme-h: 32; --bulma-scheme-s: 28%; " +
        "--bulma-primary-h: 14deg; --bulma-primary-s: 58%; --bulma-primary-l: 40%; " +
        "--bulma-link-h: 16deg; --bulma-link-s: 65%; --bulma-link-l: 34%; " +
        "--bulma-info-h: 178deg; --bulma-info-s: 55%; --bulma-info-l: 27%; " +
        "--bulma-success-h: 95deg; --bulma-success-s: 25%; --bulma-success-l: 31%; " +
        "--bulma-warning-h: 42deg; --bulma-warning-s: 92%; --bulma-warning-l: 50%; " +
        "--bulma-danger-h: 2deg; --bulma-danger-s: 62%; --bulma-danger-l: 38%"
    )
  })
})

describe("contrastWarnings", () => {
  it("flags only the known dark-accent gap for the Southwest defaults", () => {
    // As a custom scheme no dark primary lift applies, so terracotta at 40%
    // sits below 3:1 against the dark background — the one honest warning.
    expect(contrastWarnings(SOUTHWEST)).toEqual([
      expect.stringContaining("Primary blends into the dark background"),
    ])
  })

  it("flags a pale primary as unreadable button text", () => {
    const warnings = contrastWarnings({ ...SOUTHWEST, primary: "#ffe680" })
    expect(warnings.some((warning) => warning.includes("Primary is hard to read as button text"))).toBe(true)
  })

  it("flags a saturated tint that sinks muted text", () => {
    const warnings = contrastWarnings({ ...SOUTHWEST, tint: "#00ff88" })
    expect(warnings.some((warning) => warning.includes("Muted text"))).toBe(true)
  })
})
