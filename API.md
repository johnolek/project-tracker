# Project Tracker API (v1)

Token-authenticated JSON API for driving the tracker from scripts and AI agents.

## Authentication

Create a key in the web UI at `/settings/api_keys`. The plaintext token (`pt_...`)
is shown once at creation — store it immediately. Send it on every request as a
Bearer token:

```bash
curl http://localhost:3000/api/v1/projects \
  -H "Authorization: Bearer pt_YOUR_TOKEN"
```

Every request is scoped to the key's organization; resources belonging to other
organizations behave as if they don't exist (404).

Missing or invalid token:

```json
{ "error": "Invalid or missing API token" }   // 401
```

## Error shapes

| Status | Body | When |
|---|---|---|
| 401 | `{ "error": "Invalid or missing API token" }` | No/bad Bearer token |
| 404 | `{ "error": "Not found" }` | Resource missing or belongs to another organization |
| 422 | `{ "error": "<message>" }` | Missing required param wrapper, unknown status name, advancing past the final status |
| 422 | `{ "errors": ["Title can't be blank", ...] }` | Model validation failures |

## Resource shapes

Single resources are returned as a bare JSON object. Indexes are wrapped in an
envelope keyed by the collection name; only item indexes are paginated.

**Item**

```json
{
  "id": 42,
  "key": "TRAC-12",
  "number": 12,
  "title": "Fix login crash",
  "item_type": "bug",
  "points": 3,
  "strength": 0.0,
  "status": { "id": 1, "name": "New", "category": "open", "position": 1 },
  "project": { "id": 7, "name": "Tracker", "slug": "TRAC" },
  "tags": ["backend", "urgent"],
  "notes_html": "<div class=\"trix-content\">\n  <p>Steps to reproduce...</p>\n</div>\n",
  "notes_text": "Steps to reproduce...",
  "created_at": "2026-07-17T12:00:00.000Z",
  "updated_at": "2026-07-17T12:00:00.000Z"
}
```

- `key` / `number` — human-readable reference (`<project slug>-<number>`) and the item's project-scoped sequence number. Numbers are assigned on creation and never reused, even after deletion. Every item endpoint accepts the key in place of the numeric `id` (case-insensitively), so a known key never requires listing items first.
- `tags` — names sorted alphabetically.
- `notes_html` — the rendered rich-text HTML (wrapped in a `trix-content` div); `""` when notes are blank.
- `notes_text` — plain-text rendering of the notes; `""` when blank.
- `strength` / `points` — Bradley-Terry priority log-strength (float; comparisons are project-scoped, so strengths order items within a project; higher means higher priority) and estimation points (integer or null).

**Project** `{ id, name, slug, created_at, updated_at }` — `slug` is 1-10 uppercase letters/digits starting with a letter (e.g. `TRAC`), unique per organization
**Status** `{ id, name, category, position }` — `category` is one of `open`, `in_progress`, `done`
**Tag** `{ id, name }`
**Comment** `{ id, body, body_html, body_text, source, user: { id, username }, created_at }`

- `body_html` — the rendered rich-text HTML (wrapped in a `trix-content` div); `""` when blank.
- `body_text` — plain-text rendering of the body; `""` when blank.
- `body` — alias of `body_text`, kept for backward compatibility.
- `source` — `"web"` (posted from the web UI) or `"api"` (posted through this API; every comment created via `POST` is stamped `"api"`).

## Projects

```bash
# List (alphabetical)
curl http://localhost:3000/api/v1/projects \
  -H "Authorization: Bearer pt_YOUR_TOKEN"
# => { "projects": [ { "id": 7, "name": "Tracker", ... } ] }

# Show
curl http://localhost:3000/api/v1/projects/7 \
  -H "Authorization: Bearer pt_YOUR_TOKEN"

# Create (201). slug is optional — derived from the name when omitted
# (first word, upcased, cut to 4 chars: "Website Redesign" -> "WEBS").
curl -X POST http://localhost:3000/api/v1/projects \
  -H "Authorization: Bearer pt_YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ "project": { "name": "Website Redesign", "slug": "WEB" } }'

# Rename. slug may also be changed here, but only while the project has no
# items — once items exist the slug is frozen so keys stay stable (422).
curl -X PATCH http://localhost:3000/api/v1/projects/7 \
  -H "Authorization: Bearer pt_YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ "project": { "name": "Website v2" } }'

# Delete (204, destroys the project's items too)
curl -X DELETE http://localhost:3000/api/v1/projects/7 \
  -H "Authorization: Bearer pt_YOUR_TOKEN"
```

## Items

### Listing and filtering

Two index routes, both returning the paginated envelope
`{ "items": [...], "page": 1, "per_page": 25, "total": 4 }` (`total` is the
filtered count across all pages):

- `GET /api/v1/items` — all items in the organization
- `GET /api/v1/projects/:project_id/items` — one project's items

All filters combine (AND) and are available on both routes:

| Param | Meaning |
|---|---|
| `project_id` | Limit to one project (org-wide route; as a path segment on the nested route). Unknown/foreign project → 404. |
| `status` | Status **name**, case-insensitive (`status=in progress`) |
| `item_type` | One of `bug`, `task`, `enhancement`, `idea` |
| `tags` | Comma-separated tag names, case-insensitive. Default: match ANY listed tag (no duplicate rows). |
| `tags_match` | `all` — item must have every listed tag |
| `points` | Exact points value |
| `points_lt` / `points_lte` / `points_gt` / `points_gte` | Points comparisons (items with null points never match) |
| `q` | Case-insensitive substring match on title |
| `sort` | `created_at` (default), `points`, `strength`, `title` |
| `direction` | `asc` or `desc`. Defaults: `desc` for `created_at`, `asc` for the others. Ties break by `id` in the same direction. |
| `page` | Page number, default 1 |
| `per_page` | Default 25, max 100 |

```bash
# Small, urgent, still-open backend work — cheapest first
curl "http://localhost:3000/api/v1/items?status=new&tags=urgent,backend&points_lte=3&sort=points&direction=asc" \
  -H "Authorization: Bearer pt_YOUR_TOKEN"

# Search titles in one project, second page
curl "http://localhost:3000/api/v1/projects/7/items?q=login&page=2&per_page=10" \
  -H "Authorization: Bearer pt_YOUR_TOKEN"

# Items tagged with BOTH api and bug
curl "http://localhost:3000/api/v1/items?tags=api,bug&tags_match=all" \
  -H "Authorization: Bearer pt_YOUR_TOKEN"
```

### Create

`POST /api/v1/projects/:project_id/items` → 201 with the item.

Fields (all optional except `title`):

- `title` — required string
- `notes` — HTML string, stored as rich text
- `item_type` — defaults to `task`
- `points` — positive integer or null
- `status` — status **name**, case-insensitive, resolved within the organization. Omitted → the organization's default (first open) status. Unknown name → 422 `{ "error": "Unknown status: <name>" }`.
- `tags` — array of names **or** one comma-separated string; unknown tags are created automatically

```bash
curl -X POST http://localhost:3000/api/v1/projects/7/items \
  -H "Authorization: Bearer pt_YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "item": {
      "title": "Rate-limit the login endpoint",
      "notes": "<p>Five attempts per minute, then <strong>backoff</strong>.</p>",
      "item_type": "enhancement",
      "points": 3,
      "status": "in progress",
      "tags": ["backend", "security"]
    }
  }'
```

### Show / update / delete

Shallow routes, scoped to the key's organization. `:id` is the numeric id or
the item's human key — `items/42` and `items/TRAC-12` hit the same record:

```bash
curl http://localhost:3000/api/v1/items/42 \
  -H "Authorization: Bearer pt_YOUR_TOKEN"

curl http://localhost:3000/api/v1/items/TRAC-12 \
  -H "Authorization: Bearer pt_YOUR_TOKEN"

# PATCH accepts the same fields as create. `tags` REPLACES the full tag set
# (send [] to clear); omit the key to leave tags untouched.
curl -X PATCH http://localhost:3000/api/v1/items/42 \
  -H "Authorization: Bearer pt_YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ "item": { "points": 5, "status": "completed", "tags": "backend, reviewed" } }'

# Delete (204)
curl -X DELETE http://localhost:3000/api/v1/items/42 \
  -H "Authorization: Bearer pt_YOUR_TOKEN"
```

### Advance

`POST /api/v1/items/:id/advance` moves the item to the next status by position
in the organization's ordered statuses (e.g. New → In Progress → Needs
Verification → Completed). Returns 200 with the updated item, or, when already at
the last status, 422 `{ "error": "Item is already in the final status" }`.

```bash
curl -X POST http://localhost:3000/api/v1/items/42/advance \
  -H "Authorization: Bearer pt_YOUR_TOKEN"
```

## Comments

```bash
# List (chronological, oldest first)
curl http://localhost:3000/api/v1/items/42/comments \
  -H "Authorization: Bearer pt_YOUR_TOKEN"
# => { "comments": [ { "id": 1, "body": "...", "body_html": "<div class=\"trix-content\">...</div>",
#                      "body_text": "...", "source": "api",
#                      "user": { "id": 3, "username": "john" }, "created_at": "..." } ] }

# Create (201) — authored by the key's user, stamped source: "api".
# body is plain text in; it is stored as rich text (HTML comes back in body_html).
curl -X POST http://localhost:3000/api/v1/items/42/comments \
  -H "Authorization: Bearer pt_YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ "comment": { "body": "Reproduced on staging; fix in progress." } }'
```

## Statuses

Statuses are the board columns. Each has a `category` (`open`, `in_progress`, or
`done`) and a `position` that orders the columns and drives `advance`.

```bash
# List, ordered by position
curl http://localhost:3000/api/v1/statuses \
  -H "Authorization: Bearer pt_YOUR_TOKEN"
# => { "statuses": [ { "id": 1, "name": "New", "category": "open", "position": 1 }, ... ] }

# Create (201) — omit position to append at the end
curl -X POST http://localhost:3000/api/v1/statuses \
  -H "Authorization: Bearer pt_YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ "status": { "name": "Blocked", "category": "in_progress" } }'
# => { "id": 5, "name": "Blocked", "category": "in_progress", "position": 5 }

# Update (200) — rename, recategorize, or reposition
curl -X PATCH http://localhost:3000/api/v1/statuses/5 \
  -H "Authorization: Bearer pt_YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ "status": { "name": "On Hold", "position": 3 } }'

# Delete (204). Blocked (422) while items still use the status:
# { "error": "Cannot delete record because dependent items exist" }
curl -X DELETE http://localhost:3000/api/v1/statuses/5 \
  -H "Authorization: Bearer pt_YOUR_TOKEN"
```

## Tags

```bash
# Tags, ordered by name
curl http://localhost:3000/api/v1/tags \
  -H "Authorization: Bearer pt_YOUR_TOKEN"
# => { "tags": [ { "id": 9, "name": "backend" }, ... ] }
```

## Agent workflow example

Pick up the smallest open task, start it, log progress, and finish it:

```bash
TOKEN="pt_YOUR_TOKEN"
BASE="http://localhost:3000/api/v1"
AUTH="Authorization: Bearer $TOKEN"

# 1. Find the smallest open task
ITEM_ID=$(curl -s "$BASE/items?status=new&item_type=task&sort=points&direction=asc&per_page=1" \
  -H "$AUTH" | jq '.items[0].id')

# 2. Start it (New -> In Progress)
curl -s -X POST "$BASE/items/$ITEM_ID/advance" -H "$AUTH" | jq '.status.name'

# 3. Log progress
curl -s -X POST "$BASE/items/$ITEM_ID/comments" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{ "comment": { "body": "Started work; root cause identified." } }' > /dev/null

# 4. Advance toward done (In Progress -> Needs Verification -> Completed)
curl -s -X POST "$BASE/items/$ITEM_ID/advance" -H "$AUTH" | jq '.status.name'
curl -s -X POST "$BASE/items/$ITEM_ID/advance" -H "$AUTH" | jq '.status.name'
```
