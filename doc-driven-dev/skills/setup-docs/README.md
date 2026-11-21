# setup-docs

Bootstraps or audits a project's `docs/` folder. Explores the codebase for evidence, asks one question at a time, and builds the documentation incrementally into the structure that `/brief` and `/debrief` navigate.

## Invocation

```
/setup-docs              # full bootstrap or audit
/setup-docs <focus>      # narrow to a category or concern
```

Interactive throughout. Existing docs are reorganized rather than rewritten, and nothing is removed without approval.

## What it produces

```
docs/
├── _index.md              # root TOC, plus the cross-cutting axes list
├── conventions/           # how to write code in this project
├── architecture/          # how the system is structured and why
├── requirements/          # feature specs, constraints, acceptance criteria
└── planning/              # active and future work
```

- An `_index.md` in every folder, each entry with a summary so an agent can triage without opening files
- Kebab-case, single-topic files of at most 150 lines, cross-referenced across categories
- **Why:** annotations where the docs contract requires them: on a rule that replaces another or departs from a common default
- A `## Cross-cutting axes` section in the root index, which `/debrief` audits one axis per run
- A migration proposal for conventions that live in `CLAUDE.md` but belong in `docs/`

## The detector's interface

`scripts/docs-audit.sh` reports what Step 1 counts, findings before the long inventory: the contract's structure present and missing, structure faults, names that are not kebab-case, Markdown outside `docs/`, the root instruction files' headings, the axes section, the codebase's top level, and every doc with its size. Its digest stays under 20 KB (`DOCS_AUDIT_BUDGET`); the full report is at `.git/docs-audit-report.txt`, or a temp file outside git. It always exits 0, since a project with no docs is a normal start. `DOCS_AUDIT_DIR` points it at a docs root other than `docs/`. Its structure checks are the same code as `debrief`'s sweep, kept identical by the repo's `scripts/check-shared-blocks.sh`.

## Files

- `SKILL.md` — the six-step workflow, opening with the docs contract it shares with `brief` and `debrief`
- `scripts/docs-audit.sh` — the detector for the Step 1 assessment and the Step 6 recheck

The repo's `scripts/test-doc-driven-dev.sh` tests the detector, and `evidence/` holds recorded runs.

## Install

```bash
npx skills@latest add abgregs/skills@setup-docs
```
