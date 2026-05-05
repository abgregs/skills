---
name: brief
description: Pre-task briefing. Searches project docs for relevant conventions, rules, and requirements before planning code changes. Use when starting any non-trivial task involving code changes.
---

You are preparing to execute a code task. Before writing any code, you must ground yourself in the project's documentation and align your plan with established conventions.

**Task:** $ARGUMENTS

## Documentation Architecture

Project docs live in `docs/` with this structure:

```
docs/
├── _index.md              # Root TOC
├── conventions/           # How to write code in this project
│   └── _index.md
├── architecture/          # How the system is structured and why
│   └── _index.md
├── decisions/             # ADR-style — why we chose X over Y
│   └── _index.md
├── requirements/          # Feature specs, constraints, acceptance criteria
│   └── _index.md
└── planning/              # Active and future work
    └── _index.md
```

Each folder has an `_index.md` TOC. Files are kebab-case, single-topic, max ~150 lines. Each `_index.md` entry includes a brief summary so the agent can triage relevance without opening every file. Docs should cross-reference related docs (e.g., a decision doc links to the convention it produced).

## Workflow

### Step 1: Discover relevant docs

First, assess what doc structure exists:

1. Check if `docs/_index.md` exists
2. If it does, use it and the category `_index.md` files as your primary filter — read summaries to triage relevance without opening every file
3. If it doesn't, fall back to exploration: `Glob` for `docs/**/*.md`, scan filenames and headings, read what looks relevant
4. Read the specific docs that relate to the task
5. Follow any cross-references to find related docs in other categories
6. Also check `CLAUDE.md` for any rules that apply

**Do not block the task because docs are missing or poorly structured.** Work with whatever exists. If the structure doesn't match the target architecture, note the gaps but proceed — the goal is to find applicable rules, not to fix the doc structure right now.

### Step 2: Identify applicable rules and conventions

List every convention, rule, pattern, or requirement from the docs that applies to this task. Group them by source file so the user can verify. Format:

```
**Applicable rules:**

From `docs/conventions/components.md`:
- Rule 1
- Rule 2

From `docs/architecture/data-flow.md`:
- Rule 3

From `CLAUDE.md`:
- Rule 4
```

If docs exist but in a different structure (no `_index.md`, flat folder, different naming), still extract the applicable rules — just note the structural gaps as findings for `/debrief`.

If no docs exist at all and no `CLAUDE.md` conventions are found, recommend `/setup-docs` before proceeding. But if there's *any* useful documentation — even disorganized — use it and move forward.

### Step 3: Check if docs need updates before starting

Evaluate whether the task itself signals a need to update docs *before* implementation:

- Does the task introduce a new pattern that should be documented?
- Does the task contradict an existing convention? If so, should the convention change?
- Are there gaps in the docs that would leave future tasks unguided?

If doc changes are needed, propose them now and get user confirmation before proceeding to the plan. Make the edits (updating `_index.md` files as needed) so the plan in Step 4 can reference the updated conventions.

### Step 4: Propose an aligned plan

Enter plan mode and propose your implementation plan. The plan must:

- Explicitly reference which conventions/rules it follows
- Call out any areas where conventions are ambiguous or don't cover the situation
- Flag any tradeoffs where following one convention might conflict with another

### Step 5: Note gaps for future docs

If you discovered gaps, ambiguities, or missing cross-references during research that don't block this task but would help future tasks, list them briefly. These become candidates for `/debrief` to address after the task is complete.

### Step 6: Clarify and confirm

If anything is unclear — in the docs, the task, or how conventions apply — ask the user before proceeding. Do not guess when conventions are ambiguous.

Wait for user approval of the plan before writing any code.

## Important

- Do NOT skip doc discovery even if you think you know the codebase
- Do NOT write code during this workflow — this is planning only
- Never block a task because docs are imperfect — adapt to what exists, note what's missing
- Only recommend `/setup-docs` when there are truly no docs or conventions to work from
