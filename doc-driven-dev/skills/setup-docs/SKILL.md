---
name: setup-docs
description: Bootstrap or audit the docs/ folder structure for a project. Explores the codebase, interviews the user about conventions, and builds out documentation incrementally. Use when starting a new project or when docs need a major refresh.
---

You are setting up or auditing the project documentation structure. Work through this interactively — explore the codebase for evidence, ask the user one question at a time, and build docs incrementally.

**Focus:** $ARGUMENTS

## Documentation Architecture

The target structure:

```
docs/
├── _index.md              # Root TOC — maps categories to purpose
├── conventions/           # How to write code in this project
│   └── _index.md
├── architecture/          # How the system is structured and why
│   └── _index.md
├── requirements/          # Feature specs, constraints, acceptance criteria
│   └── _index.md
└── planning/              # Active and future work
    └── _index.md
```

**Rules:**
- `_index.md` in every folder — each entry has the filename and a brief summary so the agent can triage relevance without opening every file
- Files: kebab-case, single-topic, max ~150 lines
- If a file grows past ~150 lines, split by subtopic and update `_index.md`
- No orphan files — every doc must be listed in its folder's `_index.md`
- Cross-references: docs should link to related docs in other categories (e.g., a convention links to the architecture it depends on; a requirement links to the conventions that govern its implementation)
- Rules within docs should include a brief **Why:** annotation where the rationale isn't obvious. Required when a rule deliberately deviates from a common-pattern default (e.g., "we don't use X even though most projects do") — future agents and contributors need the rationale to avoid regressing to the default.

## Workflow

### Step 1: Assess current state

1. Check if `docs/` exists and what's in it — `Glob` for `docs/**/*.md` and list everything
2. Read `CLAUDE.md` for existing conventions
3. Scan the codebase structure (key directories, config files, package.json) to understand the project
4. If docs already exist, read them all and categorize each one:
   - **Keep as-is** — already fits the target structure and has good content
   - **Keep and relocate** — valuable content but in the wrong place
   - **Keep and split** — good content but too long or covers multiple topics
   - **Keep and merge** — small fragments that belong together
   - **Remove** — outdated, duplicated, or superseded by code/commits
   - **Needs `_index.md`** — folder has docs but no index

Present a summary:
- What exists already (with the categorization above)
- What's missing relative to the target structure
- What can be derived from the codebase vs what needs user input
- Proposed reorganization plan (moves, splits, merges, removals)

Get user confirmation on the reorganization plan before making any changes. Existing content is never deleted without explicit approval.

### Step 2: Execute reorganization (if existing docs need it)

If Step 1 identified docs to relocate, split, or merge, do that first:

1. Create the target folder structure (any missing category folders)
2. Move/rename files to their correct locations — one at a time, confirming with user if the destination is ambiguous
3. Split oversized files, preserving all content
4. Merge fragments where agreed
5. Create `_index.md` for each folder with summaries of what's now in it

Only then proceed to filling gaps.

### Step 3: Walk through each category

Go through the must-have categories one at a time. Skip categories that are already well-covered from the reorganization. For each:

1. **Explore the codebase** for evidence — look at code patterns, config, existing comments, CLAUDE.md rules
2. **Propose content** based on what you find — draft the conventions and architecture you can infer, including a brief **Why:** annotation on any rule whose rationale isn't obvious from the rule itself
3. **Ask the user** to confirm, correct, or expand — one question at a time
4. **Write the doc** once confirmed
5. **Update the folder's `_index.md`**

**Category order:**
1. `conventions/` — styling, components, data patterns, imports, git conventions
2. `architecture/` — data flow, auth, DB patterns, key structural decisions
3. `requirements/` — active feature specs or constraints (skip if none exist yet)
4. `planning/` — audit existing planning docs if they exist, add `_index.md` if missing

For each category, ask: "What else belongs here that I haven't covered?" before moving on.

### Step 4: Build the root index

After all categories are populated, create or update `docs/_index.md` with a complete map of the structure.

Then derive the project's **cross-cutting axes** — concerns whose rules span multiple docs or categories (e.g. data lifecycle, caching/staleness, auth/revocation, time handling, error propagation). Propose candidates from evidence: recurring nouns and shared resources across the docs just written. Confirm with the user, then record them in a `## Cross-cutting axes` section of `docs/_index.md`, one line per axis with a `last audited:` date (`never` for new axes). `/debrief` audits one axis per run to catch rules that are individually correct but compose badly across docs.
**Why:** task-scoped doc traversal only reads diff-adjacent files, so conflicts between rules in unrelated docs are invisible without a cross-cutting sweep; persisting the list keeps the rotation stable so audit coverage accumulates across sessions.

### Step 5: Migration check

If conventions currently live in `CLAUDE.md` that would be better placed in `docs/`:
- Propose moving them (CLAUDE.md keeps the directive to use `/brief` and `/debrief`, plus anything that must be in CLAUDE.md specifically)
- Do NOT move anything without user confirmation
- Keep CLAUDE.md as the authoritative source for build commands, environment setup, and quick-reference rules that Claude needs on every interaction

### Step 6: Summary

Present:
- Docs reorganized (what moved, split, merged, or removed)
- Docs created (list with brief descriptions)
- Docs updated
- Any gaps that still need filling (mark as TODOs in the relevant `_index.md`)
- Recommended next steps

## Important

- Ask questions one at a time — do not dump a list of 10 questions
- Always explore the codebase before asking — propose answers based on evidence, let the user confirm or correct
- Do not create placeholder docs with no real content — either write substantive content or note it as a TODO in `_index.md`
- Respect existing docs — update and reorganize, don't delete and rewrite unless the user agrees
