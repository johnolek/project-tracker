import { describe, it, expect, afterEach } from "vitest"
import hasTextSelection from "../../app/javascript/text_selection"

describe("hasTextSelection", () => {
  afterEach(() => {
    window.getSelection().removeAllRanges()
    document.body.innerHTML = ""
  })

  it("is false with no selection", () => {
    expect(hasTextSelection()).toBe(false)
  })

  it("is false for a collapsed (caret) selection", () => {
    document.body.innerHTML = "<p>some notes</p>"
    const range = document.createRange()
    range.setStart(document.querySelector("p").firstChild, 2)
    range.collapse(true)
    window.getSelection().addRange(range)

    expect(hasTextSelection()).toBe(false)
  })

  it("is true while text is selected", () => {
    document.body.innerHTML = "<p>some notes</p>"
    const range = document.createRange()
    range.selectNodeContents(document.querySelector("p"))
    window.getSelection().addRange(range)

    expect(hasTextSelection()).toBe(true)
  })
})
