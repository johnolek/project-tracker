# Project Tracker

Personal project/item tracker. Rails 8.1, PostgreSQL, passkey-only auth (WebAuthn), Hotwire, Bulma with a custom Southwest theme. Single real user; Claude drives it mostly through the JSON API.

## Using the tracker API

- Credentials live in `config/claude_api.key` (gitignored): `URL=` and `TOKEN=` lines. Read it before API work.
- All endpoints documented in `API.md`. Auth: `Authorization: Bearer <TOKEN>`.
- Workflow conventions: fetch work with filters (e.g. `GET /api/v1/items?status=new&points_lte=2`), log progress as comments on the item, move it along with `POST /api/v1/items/:id/advance`.
- Tags auto-create on use; pass `tags` as an array or comma-separated string.

## Development

- JS bundles with esbuild, CSS with dart-sass, both via yarn into `app/assets/builds/` (gitignored). No importmap, no foreman — `bin/dev` runs the server plus `watch:css`/`watch:js`; John usually runs the server through RubyMine instead, with the watch scripts as npm run configurations.
- Stimulus controllers register explicitly in `app/javascript/controllers/index.js`.
- Tests: `bundle exec rspec`. Request specs authenticate with `register_passkey(username:)` (WebAuthn FakeClient); API specs use `spec/support/api_helpers.rb`.
- Browser verification: Playwright (devDependency) with a CDP virtual authenticator handles the passkey flow; see the pattern in past session scratchpads if needed.
- Theme: seed palette in `app/assets/stylesheets/application.sass.scss`. Any color change must keep WCAG AA contrast in BOTH light and dark schemes (verify against built CSS values, not intended ones). Scope light-theme variable overrides so they don't leak into dark mode.

## Direction

- Item ranking (future) uses Bradley-Terry fitted from the `comparisons` table — not Elo/Glicko. The Glicko columns on items are vestigial until then.
- Public board/anonymous submissions were removed deliberately; don't reintroduce.
