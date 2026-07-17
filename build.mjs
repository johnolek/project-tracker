import * as esbuild from "esbuild"
import sveltePlugin from "esbuild-svelte"

const watch = process.argv.includes("--watch")
const minify = process.argv.includes("--minify")

// css: "injected" keeps component styles out of the build output so the
// sass pipeline stays the sole writer of app/assets/builds/application.css.
const options = {
  entryPoints: ["app/javascript/application.js"],
  bundle: true,
  format: "esm",
  sourcemap: true,
  minify,
  outdir: "app/assets/builds",
  conditions: ["svelte", "browser"],
  plugins: [sveltePlugin({ compilerOptions: { css: "injected" } })],
  logLevel: "info",
}

if (watch) {
  const context = await esbuild.context(options)
  await context.watch()
} else {
  await esbuild.build(options)
}
