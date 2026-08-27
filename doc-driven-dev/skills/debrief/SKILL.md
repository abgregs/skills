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
5. **Read from disk, in full — never from memory.** Every doc you assess must
   be freshly `Read` end-to-end during this debrief. This applies most of all
   to docs you yourself wrote or edited earlier in the session: those are the
   ones most likely to be "reviewed" from conversation memory — which is no
   review at all, since memory predates the newest decisions.

For each relevant doc, assess:
- **Still accurate?** Does the doc still correctly describe how things work after these changes?
- **Still complete?** Are there new patterns, conventions, or rule changes introduced by the changes that aren't documented (including the **Why:** for any rule that replaces an existing one)?
- **Still relevant?** Did the changes make any documented convention obsolete?

### Step 3: Propose doc updates

First, classify each proposed update as one of:

- **New rule** — adds a convention/architecture/requirement that didn't exist before
- **Replacement** — overwrites or contradicts an existing rule (the previous way is no longer how we do it)
- **Clarification** — refines or expands an existing rule without changing its substance
- **Removal** — drops a rule that's no longer applicable

The classification drives the **Why:** requirement on the new or revised rule:

- **Replacements require a one-line `**Why:**` annotation.** When a rule replaces an existing one, future tasks need to know what changed and why — otherwise an agent encountering old code, partial migrations, or familiar-looking patterns may drift back to the previous approach. The Why is mandatory, not optional.
- **New rules should include a `**Why:**` annotation when the rationale isn't obvious from the rule itself.** Heuristic: if a contributor reading the rule cold would ask "why?", add the line.
- **Clarifications and removals** don't require a Why, but include one if the change was driven by a specific incident or constraint worth preserving.

Then present the proposed changes, grouped by type:

**Updates needed:**
```
Update `docs/conventions/dates-and-times.md`:
- Replace "store and pass timestamps in the user's local time" with "store and pass timestamps in UTC; convert to local time only at the display boundary"
  **Why:** removes timezone math from every internal layer and stops DST-driven off-by-one bugs at integration points
- Remove the example showing a Date object passed straight from the form into storage

Update `docs/conventions/_index.md`:
- Update the dates-and-times summary to reflect the UTC boundary rule
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

**Content checks — run these as procedures, not assessments.** An assessment
question ("is anything stale?") invites "looks fine"; a search produces
findings. Each of the following must be executed with actual tool calls:

6. **Retired-terms sweep.** Write down the vocabulary this task's decisions
   retired or renamed — old rule/feature/state names, superseded counts and
   values ("four emails" after a change to three), replaced mechanism names,
   outdated date stamps. Grep the ENTIRE docs corpus for each term. Every hit
   is either fixed or explicitly justified in the report (a frozen artifact, a
   **Why:** clause recording history). An empty retired-terms list is only
   plausible when the task changed no rules or names.
7. **Referrer closure.** For each doc changed (by the task or by this
   debrief), grep the corpus for inbound references — links to the file AND
   mentions of its concepts — and read every referrer. The usual laggards:
   `_index.md` summaries, living status docs (`current_focus.md` and kin),
   and sibling docs in other categories. While there, verify freshness stamps
   ("Updated YYYY-MM-DD") on every doc touched.
8. **Inconsistencies & cross-references** — do any docs contradict each other;
   do related docs in different categories link to each other? (e.g., a
   convention links the architecture doc it depends on)

**Cross-cutting axis audit (one axis per debrief):**

9. Read the `## Cross-cutting axes` section of `docs/_index.md`. Select ONE axis: if `$ARGUMENTS` names one, use it; otherwise prefer the axis most implicated by this task's diff; otherwise the least-recently-audited. If the section is missing, derive candidate axes from the corpus (recurring nouns and shared resources across `_index.md` summaries), confirm with the user, and create it.
10. Sweep the whole corpus for rules touching the selected axis, regardless of category — use `_index.md` summaries to shortlist, then read the matches. Evaluate whether the rules *compose*: rules can be individually accurate yet coexist badly (e.g. "cache API responses for 1 hour" and "account deletion propagates within 15 minutes" conflict without either being wrong). For each bad composition, present the applicable resolutions via AskUserQuestion — amend rule A to respect rule B, amend rule B, keep both and add an explicit precedence carve-out cross-referenced from both docs, or defer as an open item when the tension needs a code or product decision outside debrief's scope — with your recommended option first and its reasoning attached. Never pick a winner silently: which rule bends is a business tradeoff, not a doc fix. Classify the chosen resolution per Step 3 (amendments are Replacements and require a **Why:** recording what lost and why).
11. Update the selected axis's `last audited:` date. If the task revealed a new cross-cutting concern, propose adding it to the list.

**Why:** debrief's traversal is diff-scoped, so rules in docs never read together can conflict undetected; auditing one persisted axis per run bounds the cost while coverage accumulates across sessions.

Report the health check results. Fix any issues found (with user confirmation for non-trivial changes).

**Incremental structural improvements (max 1-2 per debrief):**

If the doc structure doesn't match the target architecture, propose one or two small structural fixes alongside the content updates. Examples:
- Add a missing `_index.md` to a folder that has docs
- Add summaries to `_index.md` entries that are filename-only
- Rename a file to kebab-case
- Move a doc to the correct category folder

Do not attempt a full restructure — keep it incremental so it doesn't overwhelm the debrief. If the structure needs significant work (missing categories, no index files, docs scattered outside `docs/`), recommend `/setup-docs` for a dedicated pass.

### Step 6: Adversarial second pass, then summary

Before writing the summary, assume the user's next message will be:
"double-check for stale items and cross-cutting concerns, just to be extra
sure." Run that follow-up NOW, inside this debrief: redo the retired-terms
sweep and referrer closure with fresh greps and fresh full reads of the two
or three most-edited docs, deliberately trying to prove the first pass
missed something. Fold anything found into this debrief's fixes. The
quality bar for this skill is that a real "be extra sure" follow-up finds
nothing — empirically, a casual single pass does not meet it.

Present a final summary:
- Docs updated (with brief description of each change)
- Docs created (with brief description)
- Health check results (clean, or issues fixed), each with its evidence
- Second-pass findings — what the adversarial re-sweep caught, or "nothing; first pass held"
- Axis audited, with any coexistence findings
- Any open items that need attention later

## Important

- Do NOT skip the review even if the changes seem minor — small changes can invalidate docs
- **Every health-check item in the report must cite its evidence** — the grep that was run or the file that was read. "Checked, no issues" with no named check is not a result; it is the exact failure mode this skill exists to prevent.
- Do NOT delete doc content without user confirmation
- Prefer updating existing docs over creating new ones — only create new files when the topic genuinely doesn't fit anywhere
- Keep `_index.md` files concise — one line per entry with a brief summary (summaries are how the agent triages relevance without opening every file)
- When creating or updating docs, add cross-references to related docs in other categories
