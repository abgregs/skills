# brief

Pre-task briefing. Before any code is written, discovers the project docs that bear on the task, extracts the rules and conventions they impose, and proposes an implementation plan that cites them.

## Invocation

```
/brief <task>
```

Run it at the start of any non-trivial code task. It ends in plan mode, waiting for approval; no code is written inside the skill.

## What it produces

- The doc-scout report in the transcript: the full doc inventory, index summaries, a relevance ranking for the task's keywords, and the headings of the shortlisted files
- An **Applicable rules** list grouped by source file, each rule cited as `file:line`, with any **Why:** annotation carried forward verbatim
- Proposed doc updates when the task itself changes or contradicts a convention, made before planning so the plan can reference them
- A plan that names the conventions it follows and flags where they are ambiguous or conflict
- Gaps noted for `/debrief` to close later

It works with whatever docs exist and never blocks on an imperfect structure; it recommends `/setup-docs` only when there are no docs or conventions at all.

## Files

- `SKILL.md` — the six-step workflow
- `scripts/doc-scout.sh` — the detector: enumerates docs and ranks relevance in one call, so discovery cannot be skipped

## Expected project layout

A `docs/` folder with `_index.md` files per category (`conventions/`, `architecture/`, `requirements/`, `planning/`), as bootstrapped by `/setup-docs`. See the group README for the full architecture.

## Install

```bash
npx skills@latest add abgregs/skills@brief
```
