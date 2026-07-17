---
name: tracker
description: Manage items in John's project tracker (create/fetch/filter tasks, advance them through statuses, comment progress) via bin/tracker. Use whenever asked to file, find, work, or update tracker items.
---

# Tracker

Drive the deployed project tracker through `bin/tracker` (run from the repo root). It reads credentials from `config/claude_api.key` and talks to the JSON API documented in `API.md`.

## Commands

```
bin/tracker projects
bin/tracker create-project --name "Name"
bin/tracker items --status new --points-lte 2        # filters combine freely
bin/tracker items --tags api,ui --tags-match all --sort points --direction asc
bin/tracker item 42
bin/tracker create-item PROJECT_ID --title "..." --type task --points 2 \
    --tags "ui, quick-win" --notes "<p>HTML notes</p>"
bin/tracker update-item 42 --status "In Progress" --points 3
bin/tracker advance 42                               # next status in the workflow
bin/tracker comment 42 --body "Done: moved X to Y"
bin/tracker comments 42
bin/tracker delete-item 42
bin/tracker statuses
bin/tracker tags
```

Items filters: `--status` (name), `--type` (bug|task|enhancement|idea), `--tags` (comma list, any-match; add `--tags-match all`), `--points` / `--points-lt` / `--points-lte` / `--points-gt` / `--points-gte`, `--q` (title search), `--project-id`, `--sort` (created_at|points|rating|title), `--direction`, `--page`, `--per-page`.

## Conventions

- Item types: `bug`, `task`, `enhancement`, `idea`. Tags auto-create on use — reuse existing tag names where sensible (`bin/tracker tags` to check).
- When working an item: `advance` it to In Progress, log meaningful progress/decisions as comments, `advance` again when done.
- Notes accept HTML (ActionText-sanitized on render). Plain text works but loses formatting.
- Errors print `HTTP <code>` plus the API's JSON error to stderr and exit 1. A 404 usually means a wrong ID; 422 explains itself.
