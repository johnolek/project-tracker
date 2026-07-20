// jsdom has no Web Animations API; Svelte transitions (fade) call
// element.animate and wait on onfinish. Complete instantly so outroing nodes
// leave the DOM instead of lingering forever.
if (!Element.prototype.getAnimations) {
  Element.prototype.getAnimations = () => []
}

if (!Element.prototype.animate) {
  Element.prototype.animate = function () {
    return {
      cancel() {},
      finish() {},
      play() {},
      pause() {},
      finished: Promise.resolve(),
      get onfinish() {
        return null
      },
      set onfinish(callback) {
        queueMicrotask(callback)
      },
      get oncancel() {
        return null
      },
      set oncancel(_) {},
    }
  }
}
