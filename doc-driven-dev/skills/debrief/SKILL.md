---
name: debrief
description: Post-task debrief. Reviews code changes against project docs, proposes doc updates for new patterns or convention changes, and maintains doc health. Use after completing any non-trivial code task.
---

You have just completed a code task. Now review the changes against project documentation to ensure docs stay aligned with the codebase.

**Context:** $ARGUMENTS

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
- **Why: lines.** A rule carries a one-line **Why:** when it replaces an earlier rule or departs from a common default, both required, and when a reader meeting it cold would ask why. The Why is what stops a later agent drifting back to the old rule or the default.
- **Cross-cutting axes.** `docs/_index.md` ends with `## Cross-cutting axes`: one line per concern whose rules span several docs, written `- <axis>: <what it covers> · last audited: <YYYY-MM-DD or never>`.
<!-- # --- end docs contract --- -->

## The detector

`bash <skill-base-dir>/scripts/doc-sweep.sh`, run from inside the project repo (the skill's base directory is announced when this skill loads). Enumeration is the script's job and judgment is yours: never re-derive by hand what it reports. It keeps its state in the repo's git directory, so nothing lands in the working tree, and every worktree shares the last debrief's mark.

| Call | When | Exit |
|---|---|---|
| `--scope [--base <rev>]` | Step 1: picks the base this debrief compares against, prints it with the commits and change stat since | 0; 1 when not in a git repo or `<rev>` is not a commit |
| no flag | Step 5 and Step 6: the sweep. A digest with the findings first, each under an ID, and the full report at the path it prints | 0; 1 when there is no `docs/` (set `DOC_SWEEP_DIR` when the docs live elsewhere) |
| `--verdicts -` | Step 5 and Step 6: adds the verdict lines it reads on stdin to this debrief's, then checks every finding of the last sweep has one | 0 all judged; 2 a finding has no verdict or no reason, each named; 3 no sweep has run in this worktree |
| `--mark` | the end: records HEAD as the next debrief's base | 0; 2 refused while a finding of the last sweep has no verdict, each named |

Read every digest whole, never through `head`, `sed`, or `grep`. When it says it was cut, it names the sections it left out: read those in the full report it names. Every verdict result ends with its exit code in parentheses, so there is no need to echo `$?`.

## Workflow

### Step 1: Understand what changed

1. Run `doc-sweep.sh --scope`. When the task names its own range (a PR, a branch, a commit such as `47ee8a7..HEAD`), pass where it starts: `--scope --base origin/main`. Without `--base` the script takes the last debrief's mark when it is an ancestor of HEAD, else the merge-base with the default branch; it prints the base it used and why, and the sweep in Step 5 reuses it.
2. Read the change with the `git diff <base>` command it prints, and summarize it briefly: what was added, modified, or removed.

### Step 2: Review changes against docs

Review even a small change: one renamed term can leave a doc wrong.

1. Navigate with `docs/_index.md` and the category indexes; with no index, list `docs/**/*.md`.
2. Read the docs that relate to the changed code, and `CLAUDE.md` for any rule the change touches.
3. **Read from disk, in full — never from memory.** Every doc you assess must be freshly `Read` end to end during this debrief. This applies most of all to docs you yourself wrote or edited earlier in the session: those are the ones most likely to be "reviewed" from conversation memory, which is no review at all, since memory predates the newest decisions.

For each relevant doc, assess:
- **Still accurate?** Does the doc still correctly describe how things work after these changes?
- **Still complete?** Are there new patterns, conventions, or rule changes the changes introduced that aren't documented, including the **Why:** for any rule that replaces an existing one?
- **Still relevant?** Did the changes make any documented convention obsolete?

### Step 3: Propose doc updates

Classify each proposed update as one of:

- **New rule** — adds a convention, architecture, or requirement that didn't exist before
- **Replacement** — overwrites or contradicts an existing rule (the previous way is no longer how we do it)
- **Clarification** — refines or expands an existing rule without changing its substance
- **Removal** — drops a rule that's no longer applicable

The classification and the contract's **Why:** triggers decide the line:

- **Replacement**: a **Why:** is required. An agent meeting old code, a partial migration, or a familiar pattern drifts back to the previous approach unless the doc says what changed and why.
- **New rule**: a **Why:** is required when the rule departs from a common default, and belongs whenever a contributor reading the rule cold would ask "why?".
- **Clarification** and **Removal**: a **Why:** only when a specific incident or constraint drove the change.

Then present the proposed changes, grouped by type:

```
**Updates needed:**

Update `docs/<category>/<file>.md`:
- <Replace | Add | Clarify | Remove> "<old wording>" with "<new wording>"
  **Why:** <one line — required for replacements>

Update `docs/<category>/_index.md`:
- <summary line to change>
```

A filled-in proposal for a convention replacement, with its **Why:** line, is in `<skill-base-dir>/examples/doc-update-proposal.md`.

If no updates are needed, say so explicitly and explain why the existing docs already cover the changes.

Use AskUserQuestion to confirm the proposed changes before making them; a deletion of doc content needs its own approval there.

### Step 4: Execute doc updates

For each approved change:

1. Edit the existing doc that fits; create a new file only when the topic fits nowhere.
2. Update its `_index.md` entry, and link related docs in other categories.
3. If the edit pushes the file past the contract's limit, split it into focused docs and index them.

### Step 5: Doc health check — detector + judge

1. **Run the sweep**: `doc-sweep.sh`. It diffs the docs from this debrief's base and reports, each finding under an ID:
   - **T** retired terms: phrases and words on removed doc lines that no added line uses, with every place the corpus still uses them. Phrases come first, then the words removed most often; the digest names any the cap of 40 dropped, so grep those yourself when they matter.
   - **R** referrers: unchanged docs that link a changed doc or repeat one of its headings.
   - **F** freshness: an `Updated YYYY-MM-DD` stamp older than its file's last commit.
   - **S** structure in the docs this change touched: dead links, orphans, a folder with docs and no `_index.md`, an index entry with no summary, a file over the contract's limit.

   Structure faults in docs the change did not touch are listed as standing, with no ID and no verdict; they are where the incremental structural improvements below come from. It also lists the cross-cutting axes with their `last audited:` dates, for the axis audit.
2. **Judge every finding — the judge half.** Give each ID one line, `<ID> FIX <what you changed>` or `<ID> JUSTIFY <reason>`, and send them on stdin; there is no file to write:

   ```
   bash <skill-base-dir>/scripts/doc-sweep.sh --verdicts - <<'EOF'
   T-3aa8 FIX reworded api-endpoints.md to the bearer token
   R-ba65 JUSTIFY the index summary still describes auth.md
   EOF
   ```

   A reason to keep a hit: a frozen artifact, a **Why:** clause recording history, or the same word in a different sense (a rule that bans "resets" legitimately contains the word). Make the fixes, with the user's confirmation for any that change a rule's substance.
3. **Cover the detector's blind spots yourself:**
   (a) **session-decision terms**: vocabulary retired by THIS session's decisions that isn't on disk yet (a diff cannot see chat); grep the corpus for each;
   (b) **semantic staleness and absences**: read the two or three most-edited docs end to end, hunting for dead-model semantics written in fresh words and for missing entries (an incomplete list has no string to grep for);
   (c) **inconsistencies and cross-references**: do any docs contradict each other, and do related docs in different categories link each other?

**Cross-cutting axis audit (one axis per debrief):**

4. Take the axes from the sweep's axes section. Select ONE: if `$ARGUMENTS` names one, use it; otherwise prefer the axis most implicated by this task's diff; otherwise the least-recently-audited. If the section is missing, derive candidate axes from the corpus (recurring nouns and shared resources across `_index.md` summaries), confirm them with the user, and create the section in the contract's format.
5. Sweep the whole corpus for rules touching the selected axis, regardless of category: use `_index.md` summaries to shortlist, then read the matches. Evaluate whether the rules *compose*: rules can be individually accurate yet coexist badly (e.g. "cache API responses for 1 hour" and "account deletion propagates within 15 minutes" conflict without either being wrong). For each bad composition, present the applicable resolutions via AskUserQuestion — amend rule A to respect rule B, amend rule B, keep both and add an explicit precedence carve-out cross-referenced from both docs, or defer as an open item when the tension needs a code or product decision outside debrief's scope — with your recommended option first and its reasoning attached. Never pick a winner silently: which rule bends is a business tradeoff, not a doc fix. Classify the chosen resolution per Step 3 (amendments are Replacements and require a **Why:** recording what lost and why).
6. Update the selected axis's `last audited:` date. If the task revealed a new cross-cutting concern, propose adding it to the list.

**Why:** debrief's traversal is diff-scoped, so rules in docs never read together can conflict undetected; auditing one persisted axis per run bounds the cost while coverage accumulates across sessions.

**Incremental structural improvements (max 1-2 per debrief):** propose one or two small fixes alongside the content updates, taken from the sweep's standing faults or from structure that doesn't match the contract, such as a missing index, a dead link, or a doc in the wrong category. Do not attempt a full restructure; if the structure needs significant work (missing categories, docs scattered outside `docs/`), recommend `/setup-docs` for a dedicated pass.

### Step 6: Adversarial second pass, then summary

Before writing the summary, assume the user's next message will be: "double-check for stale items and cross-cutting concerns, just to be extra sure." Run that follow-up NOW, inside this debrief: re-run the sweep (the fixes just made may themselves have referrers), re-grep your session-decision terms, and take fresh full reads of the most-edited docs, deliberately trying to prove the first pass missed something. Fold anything found into this debrief's fixes. The quality bar for this skill is that a real "be extra sure" follow-up finds nothing.

Then run `doc-sweep.sh --verdicts -` with a line for each ID the re-sweep added; the verdicts already given still count:
- **exit 0**: every finding is judged; write the summary.
- **exit 2**: it names each finding with no verdict or no reason. Send those lines, then rerun. If it stops a second time on a finding you cannot judge, ask the user about that finding.
- **exit 3**: no sweep ran in this worktree; run the sweep, then the check.

Present a final summary:
- Docs updated (with brief description of each change)
- Docs created (with brief description)
- Health check results: each finding's ID and verdict, the `--verdicts` result, and the blind-spot checks with the grep or read behind each. "Checked, no issues" with no named check is not a result; it is the exact failure this skill exists to prevent.
- Second-pass findings: what the re-sweep caught, or "nothing; first pass held"
- Axis audited, with any coexistence findings
- Any open items that need attention later

When the debrief is complete (fixes committed), run `doc-sweep.sh --mark` so the next debrief's diff starts from here. It refuses with exit 2 while a finding of the last sweep has no verdict: send the missing lines with `--verdicts -` and mark again. `--mark --accept-unjudged` records the base with findings unjudged; that is the user's call, so use it only when the user says to.
