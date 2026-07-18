---
name: verify
description: Build, launch, and drive this app in a browser to verify changes end-to-end (passkey auth via Playwright CDP virtual authenticator).
---

# Verifying project-tracker changes at runtime

## Build

```bash
yarn build && yarn build:css   # writes app/assets/builds/ (gitignored)
```

## Server

John usually has a RubyMine dev server on port 3003 — do NOT reuse it after
running a migration (its schema cache predates the migration; INSERTs will 500
with NotNullViolation on new columns) and do not restart it. Boot your own:

```bash
bin/rails server -p 3006 -P tmp/pids/verify.pid -d
```

Port must be 3000-3010: `config/initializers/webauthn.rb` only allows those
localhost origins in dev, and the host must be `localhost`, not `127.0.0.1`
(rp_id is `localhost`). Kill via `kill $(cat tmp/pids/verify.pid)` when done.

## Driving with Playwright

Playwright is a devDependency; only some browsers are cached. Chromium (needed
for the CDP virtual authenticator) may require `npx playwright install
chromium-headless-shell` once. Run scripts with
`NODE_PATH=$PWD/node_modules node script.js`.

Passkey signup flow (no passwords exist):

```js
const cdp = await context.newCDPSession(page)
await cdp.send("WebAuthn.enable")
await cdp.send("WebAuthn.addVirtualAuthenticator", {
  options: { protocol: "ctap2", transport: "internal", hasResidentKey: true,
             hasUserVerification: true, isUserVerified: true,
             automaticPresenceSimulation: true },
})
await page.goto(`${BASE}/signup`)
await page.fill("input[name='username']", username)  // plain name, not registration[username]
await page.click("input[type=submit]")
await page.waitForURL((url) => !url.pathname.startsWith("/signup"))  // redirects to /
```

Gotchas:

- Turbo navigates via pushState — `waitForURL` needs `{ waitUntil: "commit" }`
  after form submits, or `load` never fires and it times out.
- The navbar has a search form on every page: never click a bare
  `input[type=submit]`; scope to the form containing the field you filled
  (`page.locator("form", { has: page.locator(sel) }).locator("input[type=submit]")`).
- Item create redirects to the item page (`/items/:id`), not the board.
- API probes: create an API key at `/settings/api_keys` (token appears in a
  `<code>` element once), then curl `http://localhost:3006/api/v1/...` with
  `Authorization: Bearer <token>`. `bin/tracker` points at the DEPLOYED
  instance, not localhost — don't use it to verify local changes.
- Dark mode: `browser.newContext({ colorScheme: "dark" })`.

## Cleanup

Test users/orgs land in the shared dev DB. Remove them:

```bash
bin/rails runner 'users = User.where("username LIKE ?", "verify-%");
orgs = users.flat_map(&:organizations).uniq;
users.each(&:destroy!); orgs.each { |o| o.destroy! if o.users.none? }'
```
