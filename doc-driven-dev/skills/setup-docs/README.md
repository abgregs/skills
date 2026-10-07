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
- Kebab-case, single-topic files under ~150 lines, cross-referenced across categories
- **Why:** annotations on rules whose rationale is not obvious, required where a rule deviates from a common default
- A `## Cross-cutting axes` section in the root index, which `/debrief` audits one axis per run
- A migration proposal for conventions that live in `CLAUDE.md` but belong in `docs/`

## Files

- `SKILL.md` — the six-step workflow

## Install

```bash
npx skills@latest add abgregs/skills@setup-docs
```
