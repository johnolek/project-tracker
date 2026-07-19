# Project Tracker

Personal project/item tracker. Rails 8.1, PostgreSQL, passkey-only auth (WebAuthn), Turbo for navigation with Svelte 5 islands for interactive UI, Bulma with a custom Southwest theme. Single real user; Claude drives it mostly through the JSON API.

## Using the tracker API

- Use `bin/tracker` — it reads `config/claude_api.key` (gitignored, `URL=`/`TOKEN=` lines) and wraps the whole API: `bin/tracker items --status new --points-lte 2`, `create-item`, `advance`, `comment`, etc. Run it with no args for the full command list. (John's machine also has a user-level `tracker` skill documenting this for sessions in other repos.)
- Raw endpoints are documented in `API.md` (`Authorization: Bearer <TOKEN>`) if the CLI doesn't cover something.
- Workflow conventions: advance an item when starting/finishing work, log progress as comments, reuse existing tags where sensible (tags auto-create on use).
- Statuses are configurable per org (web: /settings/statuses, API: statuses CRUD). Default flow: New → In Progress → Needs Verification → Completed; `advance` walks positions, so completing an item takes two advances from In Progress — Needs Verification is where work waits for John's (or a Playwright) check.

## Development

- JS bundles with esbuild via `build.mjs` (esbuild-svelte plugin), CSS with dart-sass, both via yarn into `app/assets/builds/` (gitignored). No importmap, no foreman — `bin/dev` runs the server plus `watch:css`/`watch:js`; John usually runs the server through RubyMine instead, with the watch scripts as npm run configurations.
- Interactive UI is Svelte 5 (runes), no Stimulus. Components live in `app/javascript/components/` and register in `app/javascript/islands.js`; views mount them with `data-svelte-component` + `data-props` (JSON, built by helpers in `app/helpers/application_helper.rb`). Keep component styles in `application.sass.scss` (no `<style>` blocks) so sass stays the only writer of `application.css`. Live board updates arrive over ActionCable (`BoardChannel`) as JSON upsert/remove/strengths messages — not Turbo Stream partial swaps — and the cable connection requires a signed-in session.
- Tests: `bundle exec rspec`. Request specs authenticate with `register_passkey(username:)` (WebAuthn FakeClient); API specs use `spec/support/api_helpers.rb`.
- Browser verification: Playwright (devDependency) with a CDP virtual authenticator handles the passkey flow; see the pattern in past session scratchpads if needed.
- `bin/rails db:seed` (development only) fills an organization with demo projects, items, and comparisons for manual testing. Register a passkey user first; it targets `SEED_USER=<username>` or the oldest user with a credential.
- Theme: seed palette in `app/assets/stylesheets/application.sass.scss`. Any color change must keep WCAG AA contrast in BOTH light and dark schemes (verify against built CSS values, not intended ones). Scope light-theme variable overrides so they don't leak into dark mode.

## Deployment

- Coolify builds the Dockerfile; deploy env needs `DATABASE_URL`, `RAILS_MASTER_KEY`, `WEBAUTHN_RP_ID`, `WEBAUTHN_ORIGIN`.
- Email sign-in / recovery needs SMTP env (provider-agnostic): `SMTP_ADDRESS`, `SMTP_USERNAME`, `SMTP_PASSWORD`, optional `SMTP_PORT` (587), `SMTP_AUTHENTICATION` (plain), `SMTP_DOMAIN`, plus `MAIL_FROM` and `MAIL_HOST` (falls back to the `WEBAUTHN_ORIGIN` host). Without these, magic-link emails silently don't send (delivery errors are swallowed). Dev writes emails to `tmp/mails/` instead of sending.
- Active Storage uses local disk: a persistent volume must be mounted at `/rails/storage` (Coolify → Persistent Storage) or uploads are lost on redeploy.

## Direction

- Item ranking uses Bradley-Terry fitted from the `comparisons` table (not Elo/Glicko). Prioritization is project-scoped: pairs come from one project and comparisons validate same-project. The fit lives in `app/models/bradley_terry.rb`; `Item.recompute_strengths` persists log-strengths into `items.strength` on every comparison create/destroy. Compare pairs at `/projects/:id/prioritize`, view the ranking at `/projects/:id/priorities`.
- Public board/anonymous submissions were removed deliberately; don't reintroduce.
