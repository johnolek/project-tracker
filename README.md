# Project Tracker

A personal, multi-project task tracker. This repository is the **bootstrap skeleton**:
a runnable Rails app with passkey-only authentication, a minimal domain, a live
public project surface, and a Docker deployment matching the owner's Coolify setup.

The eventual product (pairwise Elo priority ranking, fibonacci sizing, an LLM-facing
JSON API) is intentionally **not** built yet — the schema is shaped to make those
features cheap to add later.

## Requirements

- Ruby 4.0.5 (see `.ruby-version`)
- PostgreSQL 14+
- A browser/OS with a WebAuthn authenticator (Touch ID, Windows Hello, a security
  key, or a passkey-capable phone) to register and sign in

## Development setup

```bash
bundle install
bin/rails db:setup     # create, migrate (creates the dev + test databases)
bin/rails server       # http://localhost:3000
```

Run the app and visit <http://localhost:3000>. You'll be redirected to `/login`.

### How passkey authentication works locally

Authentication is **passkey-only** (WebAuthn) — there are no passwords anywhere in the
schema or the UI. It is a hand-rolled session on top of the [`webauthn`](https://github.com/cedarcode/webauthn-ruby)
gem (no Devise).

1. **Register** at `/signup`: enter a username and approve the passkey prompt. The
   browser creates a credential, the server verifies the attestation, creates your
   `User` (plus a personal organization), stores the public key, and signs you in.
2. **Sign in** at `/login`: enter your username and approve the passkey prompt. The
   server verifies the assertion against your stored credential.
3. **Sign out** via the header.

WebAuthn is scoped to a "relying party" domain. In development this defaults to
`localhost` / `http://localhost:3000` (see `config/initializers/webauthn.rb`), which is
a valid secure context for passkeys, so it works without HTTPS. In production the RP id
and origin come from environment variables (below).

Browser note: passkeys require `localhost` (not `127.0.0.1`) and a passkey-capable
device. If you only need to exercise the flow programmatically, the request specs drive
it end-to-end with the `webauthn` gem's `FakeClient`.

## Domain

- **Organization** — a tenant. Every user gets a personal organization on signup and
  is always a member of at least one. Users relate to organizations through
  **Membership** (`role`, default `owner`), so multi-org support is already possible.
- **Status** — per-organization workflow columns (`name`, `position`, `category` in
  `open`/`in_progress`/`done`). Seeded on org creation as *New / In Progress /
  Completed*. Custom statuses later won't require a schema change.
- **Project** — belongs to an organization; has an unguessable `public_token`.
- **Item** — belongs to a project and a status (`title`, `notes`, `points`,
  `item_type` in `bug`/`task`/`enhancement`/`idea`, `source` `internal`/`external`,
  optional submitter name/email) plus Glicko-2 rating fields (`rating` 1500.0,
  `rating_deviation` 350.0, `volatility` 0.06). New items default to the org's first
  open-category status.
- **Comparison** — a permanent log of pairwise judgments (`item_a`/`item_b`, judging
  `user`, `outcome` in `a_wins`/`b_wins`/`draw` — "about equal" is a legitimate
  judgment, and Glicko-2 scores draws as 0.5). The same pair may be compared
  repeatedly; validated so the items differ and share an organization (schema/model
  only; no UI yet). `#winner`/`#loser` derive the items from the outcome, nil on a
  draw.
- **Comment** — belongs to an item and a user (schema/model only; no UI yet).
- **Credential** — a user's stored WebAuthn passkey.

The authenticated UI (projects + items CRUD) is scoped to `current_user`'s default
organization.

### Architecture note: priority ranking

Priority is modelled on [Glicko-2](https://en.wikipedia.org/wiki/Glicko_rating_system)
(the `rating`/`rating_deviation`/`volatility` fields), not plain Elo. The math and the
pick-a-pair UI are a **future phase** — this bootstrap only persists the shape. Two
properties make the shape worth having now:

- The `Comparison` table is an append-only log of every human judgment, so ratings can
  be **recomputed from scratch** at any time when the parameters get tuned (a
  [`glicko2`](https://rubygems.org/gems/glicko2) gem exists for the calculation).
- Glicko-2's `rating_deviation` doubles as a **confidence signal**: items with high RD
  (rarely compared) are exactly the ones a future pairing UI should ask about next, for
  maximum information gain per click. Sorting can then offer both raw-rating order and a
  comparison-derived stack rank.

## Live views

The authed project page and the public board are **live** via Turbo Streams over
Action Cable. Creating, editing, moving (status change), or deleting an item
re-renders the shared board partial for every subscribed viewer — no refresh. The
public board subscribes anonymously (Turbo stream names are signed;
`ApplicationCable::Connection` does not require a logged-in user).

In development the Action Cable adapter is `async` (single process). In production it
is [`solid_cable`](https://github.com/rails/solid_cable) — **database-backed, no Redis**
— running in the primary database, so broadcasts work across Puma workers.

## Public project surface (no auth)

Each project exposes two public URLs keyed by its `public_token`:

- `GET /p/:public_token` — read-only board, items grouped by status (title, type,
  points). Internal `notes` are not shown.
- `GET|POST /p/:public_token/submit` — submit an idea or bug (title, description, type
  `bug`/`idea`, optional name/email). Submissions create an `Item` with `source:
  "external"` in the default "New" status and appear live on the board. A honeypot
  field provides minimal spam protection.

Unknown tokens return 404.

## Testing and linting

```bash
bundle exec rspec       # model + request specs (random order)
bundle exec rubocop     # rubocop-rails-omakase
```

The request specs exercise the full passkey register/sign-in handshake with the
`webauthn` gem's `FakeClient`. Broadcast behavior is covered at the model level. A live
browser websocket round-trip is not automated.

## Deployment (Docker / Coolify)

The `Dockerfile` mirrors the reference app's shape: a single Postgres, Puma on port
3000 behind Coolify's Traefik (which terminates TLS), Solid Queue supervised in-process
by Puma, and a `/up` health check. There is no JavaScript/CSS build step (importmap +
propshaft), so there is no Node stage.

```bash
docker build -t project_tracker .
```

On boot the container runs `db:prepare` (create/migrate) and then Puma. Solid Queue,
Solid Cable, and Active Record all share the one database configured by `DATABASE_URL`.

### Required runtime environment

| Variable            | Purpose                                              | Example                          |
| ------------------- | ---------------------------------------------------- | -------------------------------- |
| `RAILS_MASTER_KEY`  | Decrypts credentials                                 | contents of `config/master.key`  |
| `DATABASE_URL`      | Postgres connection (single database)                | `postgres://user:pw@host/db`     |
| `WEBAUTHN_RP_ID`    | Passkey relying-party id (the bare domain)           | `tracker.example.com`            |
| `WEBAUTHN_ORIGIN`   | Passkey origin (scheme + host)                       | `https://tracker.example.com`    |

Optional: `WEBAUTHN_RP_NAME` (display name), `WEB_CONCURRENCY` (Puma workers, default
2), `SOLID_QUEUE_IN_PUMA` (set to `1` in the image), `JOB_CONCURRENCY`.

Active Storage uses the local disk service (`config/storage.yml`); mount a persistent
volume at `storage/` in production for uploaded files.
