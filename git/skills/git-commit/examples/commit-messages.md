# Example commit messages

Each message below passes `commit-preflight.sh --lint`. They show the four shapes the skill produces: a subject alone, a subject with a short body, a body that leads with `Why:`, and a grouped-mode split.

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

## Body led by `Why:` — when the change has a cause from outside the code

```
fix(hotkey): derive tap start or stop from session state

- Why: a tap while the model loaded or a permission was missing swallowed the next tap
- Drop `.recording` from `TapStateMachine` and read `RiverSession` state
- Remove the cancel-time `resetTapState` workaround
```

The subject names the change but not what triggered the bug. Without the `Why:` line, a reader of `git blame` would need the PR to learn which taps went missing and when. The messages above skip `Why:`, because their subjects and bullets already carry every reason they have.

## Grouped mode — one dirty tree, two intents

Unstaged changes touched a migration, its model, and an unrelated README fix. The migration and the model are one feature, since neither works without the other. The README fix describes nothing in that feature, so it takes `docs` and a commit of its own; a README section about `archived_at` would have gone in the `feat` commit. The skill prints an overview, then commits each change after the changes it needs:

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
- A body of nine bullets — past the hard cap of 8; summarize at a higher level
- `docs(readme): fix the setup command` with a `- Why:` bullet — `docs`, `chore`, and `test` commits take none
- A `- Why:` bullet anywhere but first

## What the lint warns about

A warning stops `--commit` until the line is fixed. `--accept-warnings` is for a warning that misreads its line, such as a noun ending in -ing.

- `- Adding a null guard to parse` — a bullet opening with an -ing word; write `Add` or say what `parse` now does
- `- This should fix the flaky retry` — a hedge; a commit records what changed
- `- Clean up the settings view` — a vague opener; name what changed in the view
