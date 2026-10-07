# Example commit messages

Each message below passes `commit-preflight.sh --lint`. They show the three shapes the skill produces: a subject alone, a subject with a short body, and a grouped-mode split.

## Subject only — a simple change

```
fix(auth): expire refresh tokens on password change
```

No body: the subject says everything a reader needs, and a body would only restate it.

## Subject with body — when the bullets add information

```
feat(api): add cursor pagination to the orders endpoint

- Replace offset paging with an opaque `after` cursor in `listOrders`
- Keep `page` working for one release with a deprecation header
- Cap page size at 200 so the cursor never spans a partition
```

Bullets carry what the diff does not state: the compatibility window and the reason for the cap.

## Grouped mode — one dirty tree, two intents

Unstaged changes touched a migration, its model, and an unrelated README fix. The skill prints an overview, then commits foundational work first:

```
Planned commits:
1. feat(db): add archived_at to projects          — migration + model
2. docs(readme): fix the local setup command      — README only
```

```
feat(db): add archived_at to projects

- Add nullable `archived_at` timestamp in migration 0042
- Expose it on `Project` and filter archived rows from `Project.active`
```

```
docs(readme): fix the local setup command
```

## What the lint rejects

- `feat: Add pagination (closes #12)` — parentheses in the description, capitalised verb
- `fix(auth): expire tokens. Generated with help from an AI assistant` — provenance in the message
- A body of eight bullets for a two-file change — the body is for what the diff cannot say, not a file list
