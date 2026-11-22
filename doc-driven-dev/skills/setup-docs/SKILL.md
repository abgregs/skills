---
name: setup-docs
description: Bootstrap or audit the docs/ folder structure for a project. Explores the codebase, interviews the user about conventions, and builds out documentation incrementally. Use when starting a new project or when docs need a major refresh.
---

You are setting up or auditing the project documentation structure. Work through this interactively — explore the codebase for evidence, ask the user one question at a time, and build docs incrementally.

**Focus:** $ARGUMENTS

<!-- # --- docs contract (identical block in brief, debrief, and setup-docs SKILL.md; scripts/check-shared-blocks.sh fails on drift) --- -->
<!-- needs from the caller: nothing -->
## Docs contract

The structure these skills read and write:

```
docs/
├── _index.md              # root TOC: one line per category, then ## Cross-cutting axes
├── conventions/           # how to write code in this project
├── architecture/          # how the system is structured and why
├── requirements/          # feature specs, constraints, acceptance criteria
└── planning/              # active and future work
```

- **Indexes.** Every folder that holds docs has an `_index.md`, with one entry per doc: its link and a summary of a few words, so an agent can triage without opening the file.
- **Files.** Kebab-case and single-topic, at most 150 lines; a doc that grows past the limit splits by subtopic. The bundled scripts check the limit.
- **Cross-references.** A doc links the docs it depends on in other categories: a convention its architecture, a requirement the conventions that govern it.
- **Why: lines.** A rule carries a one-line **Why:** when it replaces an earlier rule or departs from a common default, both required, and when a reader meeting it cold would ask why. The Why is what stops a later agent drifting back to the old rule or the default. Its reason comes from a source a reader can check: the diff, a commit message, a code comment, a doc, or the user in this session. Never supply a cause none of them states: when the reason is unknown, ask the user, and with no answer, write what the rule replaces followed by `reason not recorded`.
- **Cross-cutting axes.** `docs/_index.md` ends with `## Cross-cutting axes`: one line per concern whose rules span several docs, written `- <axis>: <what it covers> · last audited: <YYYY-MM-DD or never>`.
<!-- # --- end docs contract --- -->

## Workflow

### Step 1: Assess current state — detector + judge

1. **Run the detector**: `bash <skill-base-dir>/scripts/docs-audit.sh` from inside the project (the skill's base directory is announced when this skill loads). It reports what can be counted: which parts of the contract's structure exist, the structure faults (dead links, orphans, folders with no index, entries with no summary, files over the limit), names that are not kebab-case, Markdown outside `docs/`, the headings of `CLAUDE.md` and `AGENTS.md`, the cross-cutting axes section, the codebase's top-level folders and manifests, and every doc with its size. When the digest is cut, the rest is in the full report at the path it names. Never re-derive by hand what it lists.
2. Read every existing doc it lists, the relocation candidates it names, and `CLAUDE.md`. Then categorize each doc:
   - **Keep as-is** — already fits the contract and has good content
   - **Keep and relocate** — valuable content but in the wrong place
   - **Keep and split** — good content but too long or covers multiple topics
   - **Keep and merge** — small fragments that belong together
   - **Remove** — outdated, duplicated, or superseded by code or commits
3. Read the codebase where the map points (key directories, config, manifests) to see what the docs must cover.

Present a summary:
- What exists already, with the categorization above
- What's missing relative to the contract
- What can be derived from the codebase vs what needs user input
- Proposed reorganization plan (moves, splits, merges, removals)

Get user confirmation on the reorganization plan before making any changes. Existing content is never deleted without explicit approval.

### Step 2: Execute reorganization (if existing docs need it)

If Step 1 identified docs to relocate, split, or merge, do that first:

1. Create the target folder structure (any missing category folders)
2. Move or rename files to their correct locations — one at a time, confirming with the user if the destination is ambiguous
3. Split oversized files, preserving all content
4. Merge fragments where agreed
5. Create `_index.md` for each folder with summaries of what's now in it

Only then proceed to filling gaps.

### Step 3: Walk through each category

Go through the categories one at a time, skipping any the reorganization already covers well. For each:

1. **Explore the codebase** for evidence — code patterns, config, existing comments, `CLAUDE.md` rules — before asking anything
2. **Propose content** from what you find: draft the conventions and architecture you can infer, with the **Why:** lines the contract requires
3. **Ask the user** to confirm, correct, or expand — one question at a time
4. **Write the doc** once confirmed. A category with no substantive content yet gets a TODO line in its `_index.md`, not a placeholder doc
5. **Update the folder's `_index.md`**

**Category order:**
1. `conventions/` — styling, components, data patterns, imports, git conventions
2. `architecture/` — data flow, auth, DB patterns, key structural decisions
3. `requirements/` — active feature specs or constraints (skip if none exist yet)
4. `planning/` — audit existing planning docs if they exist, add `_index.md` if missing

For each category, ask: "What else belongs here that I haven't covered?" before moving on.

### Step 4: Build the root index

After all categories are populated, create or update `docs/_index.md` with a complete map of the structure.

Then derive the project's **cross-cutting axes** — concerns whose rules span multiple docs or categories (e.g. data lifecycle, caching/staleness, auth/revocation, time handling, error propagation). Propose candidates from evidence: recurring nouns and shared resources across the docs just written. Confirm with the user, then record them in the `## Cross-cutting axes` section in the contract's format, with `never` as the date of each new axis. `/debrief` audits one axis per run to catch rules that are individually correct but compose badly across docs.
**Why:** task-scoped doc traversal only reads diff-adjacent files, so conflicts between rules in unrelated docs are invisible without a cross-cutting sweep; persisting the list keeps the rotation stable so audit coverage accumulates across sessions.

### Step 5: Migration check

If conventions currently live in `CLAUDE.md` that would be better placed in `docs/`:
- Propose moving them (CLAUDE.md keeps the directive to use `/brief` and `/debrief`, plus anything that must be in CLAUDE.md specifically)
- Do NOT move anything without user confirmation
- Keep CLAUDE.md as the authoritative source for build commands, environment setup, and quick-reference rules that Claude needs on every interaction

### Step 6: Summary

Run `docs-audit.sh` again, then present:
- Docs reorganized (what moved, split, merged, or removed)
- Docs created (list with brief descriptions)
- Docs updated
- The second audit's structure faults: none, or each one left and why
- Any gaps that still need filling (marked as TODOs in the relevant `_index.md`)
- Recommended next steps
