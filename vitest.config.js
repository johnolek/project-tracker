import { defineConfig } from "vitest/config"
import { svelte } from "@sveltejs/vite-plugin-svelte"

// JS test harness (PROJ-79) for the Svelte islands' client state machines —
// the behaviors the RSpec suite can't see. Run with `yarn test`.
export default defineConfig({
  plugins: [svelte({ hot: false })],
  resolve: {
    // Match the browser build: Svelte 5 client runtime, not SSR.
    conditions: ["browser"],
  },
  test: {
    environment: "jsdom",
    // rAF-driven Svelte transitions need jsdom's frame loop or outros stall.
    environmentOptions: { jsdom: { pretendToBeVisual: true } },
    globals: true,
    include: ["spec/javascript/**/*.test.js"],
    setupFiles: ["spec/javascript/setup.js"],
  },
})
