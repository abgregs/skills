---
name: debrief
description: Post-task debrief. Reviews code changes against project docs, proposes doc updates for new patterns or convention changes, and maintains doc health. Use after completing any non-trivial code task.
---

You have just completed a code task. Now review the changes against project documentation to ensure docs stay aligned with the codebase.

**Context:** $ARGUMENTS

## Workflow

### Step 1: Understand what changed

1. Run `git diff --stat` and `git diff` (or `git diff --cached` if changes are staged) to see all code changes
2. Summarize the changes briefly — what was added, modified, or removed

### Step 2: Review changes against docs

First, assess what doc structure exists:

1. If `docs/_index.md` exists, use it and the category `_index.md` files to navigate
2. If it doesn't, fall back to `Glob` for `docs/**/*.md` and scan what's there
3. Read specific docs that relate to the areas of code that changed
4. Also review `CLAUDE.md` for any rules that were touched

For each relevant doc, assess:
- **Still accurate?** Does the doc still correctly describe how things work after these changes?
- **Still complete?** Are there new patterns, conventions, or decisions introduced by the changes that aren't documented?
- **Still relevant?** Did the changes make any documented convention obsolete?

### Step 3: Propose doc updates

Present a clear list of proposed doc changes, grouped by type:

**Updates needed:**
```
Update `docs/conventions/components.md`:
- Add new pattern for X (introduced in this task)
- Remove reference to Y (no longer used)

New file `docs/decisions/use-canvas-for-charts.md`:
- Document why we chose canvas over SVG for chart rendering

Update `docs/conventions/_index.md`:
- Add entry for new file
```

If no updates are needed, say so explicitly and explain why the existing docs already cover the changes.

Use AskUserQuestion to confirm the proposed changes before making them.

### Step 4: Execute doc updates

For each approved change:

1. Edit or create the doc file
2. Update the relevant `_index.md` TOC
3. Ensure the file stays under ~150 lines — if an edit pushes a file over, split it into focused sub-docs and update `_index.md` accordingly

### Step 5: Doc health check

After updates are complete, do a maintenance pass covering both structure and content:

**Structural checks:**
1. Every file in each `docs/` subfolder is listed in its `_index.md` — no orphan files
2. Every entry in each `_index.md` points to a file that exists — no dead links
3. Every `_index.md` entry has a brief summary (not just a filename) — summaries are the primary filter for agent triage
4. File sizes — flag any doc over ~150 lines that should be split
5. If any `_index.md` is missing from a folder that has docs, create it

**Content checks:**
6. Inconsistencies — do any docs contradict each other or describe patterns that no longer exist in the code?
7. Missing cross-references — do related docs in different categories link to each other? (e.g., a decision doc should link to the convention it produced)
8. Stale claims — do any docs reference files, functions, or patterns that have been renamed or removed?

Report the health check results. Fix any issues found (with user confirmation for non-trivial changes).

**Incremental structural improvements (max 1-2 per debrief):**

If the doc structure doesn't match the target architecture, propose one or two small structural fixes alongside the content updates. Examples:
- Add a missing `_index.md` to a folder that has docs
- Add summaries to `_index.md` entries that are filename-only
- Rename a file to kebab-case
- Move a doc to the correct category folder

Do not attempt a full restructure — keep it incremental so it doesn't overwhelm the debrief. If the structure needs significant work (missing categories, no index files, docs scattered outside `docs/`), recommend `/setup-docs` for a dedicated pass.

### Step 6: Summary

Present a final summary:
- Docs updated (with brief description of each change)
- Docs created (with brief description)
- Health check results (clean, or issues fixed)
- Any open items that need attention later

## Important

- Do NOT skip the review even if the changes seem minor — small changes can invalidate docs
- Do NOT delete doc content without user confirmation
- Prefer updating existing docs over creating new ones — only create new files when the topic genuinely doesn't fit anywhere
- Keep `_index.md` files concise — one line per entry with a brief summary (summaries are how the agent triages relevance without opening every file)
- When creating or updating docs, add cross-references to related docs in other categories
