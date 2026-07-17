# Project Tracker

Personal project/item tracker. Rails 8.1, PostgreSQL, passkey-only auth (WebAuthn), Hotwire, Bulma with a custom Southwest theme. Single real user; Claude drives it mostly through the JSON API.

## Using the tracker API

- Use `bin/tracker` — it reads `config/claude_api.key` (gitignored, `URL=`/`TOKEN=` lines) and wraps the whole API: `bin/tracker items --status new --points-lte 2`, `create-item`, `advance`, `comment`, etc. Run it with no args for the full command list. (John's machine also has a user-level `tracker` skill documenting this for sessions in other repos.)
- Raw endpoints are documented in `API.md` (`Authorization: Bearer <TOKEN>`) if the CLI doesn't cover something.
- Workflow conventions: advance an item when starting/finishing work, log progress as comments, reuse existing tags where sensible (tags auto-create on use).

## Development

- JS bundles with esbuild, CSS with dart-sass, both via yarn into `app/assets/builds/` (gitignored). No importmap, no foreman — `bin/dev` runs the server plus `watch:css`/`watch:js`; John usually runs the server through RubyMine instead, with the watch scripts as npm run configurations.
- Stimulus controllers register explicitly in `app/javascript/controllers/index.js`.
- Tests: `bundle exec rspec`. Request specs authenticate with `register_passkey(username:)` (WebAuthn FakeClient); API specs use `spec/support/api_helpers.rb`.
- Browser verification: Playwright (devDependency) with a CDP virtual authenticator handles the passkey flow; see the pattern in past session scratchpads if needed.
- `bin/rails db:seed` (development only) fills an organization with demo projects, items, and comparisons for manual testing. Register a passkey user first; it targets `SEED_USER=<username>` or the oldest user with a credential.
- Theme: seed palette in `app/assets/stylesheets/application.sass.scss`. Any color change must keep WCAG AA contrast in BOTH light and dark schemes (verify against built CSS values, not intended ones). Scope light-theme variable overrides so they don't leak into dark mode.

## Deployment

- Coolify builds the Dockerfile; deploy env needs `DATABASE_URL`, `RAILS_MASTER_KEY`, `WEBAUTHN_RP_ID`, `WEBAUTHN_ORIGIN`.
- Active Storage uses local disk: a persistent volume must be mounted at `/rails/storage` (Coolify → Persistent Storage) or uploads are lost on redeploy.

## Direction

- Item ranking uses Bradley-Terry fitted from the `comparisons` table (not Elo/Glicko). The fit lives in `app/models/bradley_terry.rb`; `Item.recompute_strengths` persists org-relative log-strengths into `items.strength` on every comparison create/destroy. Compare pairs at `/prioritize`, view the ranking at `/priorities`.
- Public board/anonymous submissions were removed deliberately; don't reintroduce.
