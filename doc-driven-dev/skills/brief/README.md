# brief

Pre-task briefing. Before any code is written, discovers the project docs that bear on the task, extracts the rules and conventions they impose, and proposes an implementation plan that cites them.

## Invocation

```
/brief <task>
```

Run it at the start of any non-trivial code task. It ends on the plan and waits for your approval, in plan mode where the harness offers one; no code is written inside the skill.

## What it produces

- The doc-scout digest in the transcript: a relevance shortlist for the task's keywords, the headings and **Why:** lines of the shortlisted docs, the index entries that match the task, and the root instruction files' headings
- An **Applicable rules** list grouped by source file, each rule cited as `file:line`, with any **Why:** annotation carried forward verbatim
- Questions about ambiguous or conflicting conventions, asked before the plan rather than after it
- Proposed doc updates when the task itself changes or contradicts a convention, made before planning so the plan can cite them
- A plan that names the conventions it follows, flags where they are ambiguous or conflict, and lists the gaps for `/debrief` to close later

It works with whatever docs exist and never blocks on an imperfect structure; it recommends `/setup-docs` only when there are no docs or conventions at all.

## The detector's interface

`scripts/doc-scout.sh <task words>` prints a digest under 20 KB (`DOC_SCOUT_BUDGET`), findings first, so the agent reads all of it in one call; the size follows the shortlist, not the corpus. The full report, every `_index.md` whole and every doc with its line count, is written to `.git/doc-scout-report.txt` (or a temp file outside git), and the digest names the path. Words shorter than four letters are dropped as search terms. It always exits 0, including with no `docs/` or outside a git repo, since the skill never blocks on missing docs. `DOC_SCOUT_DIR` points it at a docs root other than `docs/`.

## Files

- `SKILL.md` — the five-step workflow, opening with the docs contract it shares with `debrief` and `setup-docs`
- `scripts/doc-scout.sh` — the detector: enumerates docs and ranks relevance in one call, so discovery cannot be skipped

The repo's `scripts/test-doc-driven-dev.sh` tests the detector, and `evidence/` holds recorded runs.

## Expected project layout

A `docs/` folder with `_index.md` files per category (`conventions/`, `architecture/`, `requirements/`, `planning/`), as bootstrapped by `/setup-docs`. The docs contract at the top of `SKILL.md` gives the full layout.

## Install

```bash
npx skills@latest add abgregs/skills@brief
```
