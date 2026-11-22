---
name: brief
description: Pre-task briefing. Searches project docs for relevant conventions, rules, and requirements before planning code changes. Use when starting any non-trivial task involving code changes.
---

You are preparing to execute a code task. Before writing any code, ground yourself in the project's documentation and align your plan with its conventions.

**Task:** $ARGUMENTS

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

### Step 1: Discover relevant docs — detector + judge

Discovery is enumerable, so a bundled script does it; your job is judgment on its output. Run it even when you know the codebase: its report is the evidence that discovery ran.

1. **Run the detector**: `bash <skill-base-dir>/scripts/doc-scout.sh <task keywords>` from inside the project repo (the skill's base directory is announced when this skill loads; pass the task's distinctive words, four letters or longer). It prints a digest with the findings first: a shortlist of the docs that mention task terms, ranked by rarity: a term found in few docs counts for more than one found in many, the headings and **Why:** lines of each shortlisted doc, the index entries that match the task, the headings of `CLAUDE.md` and `AGENTS.md`, and the docs per folder. The digest stays under a fixed size; the full report, every index whole and every doc with its size, is at the path the digest names.
2. **Read the digest whole**, never through `head`, `sed`, or `grep`. Findings come first, so a cut drops the least of it; the last line then names the sections left out, which the full report holds. Open the report when the shortlist misses a doc the task needs.
3. **Judge the shortlist**: term hits are recall, not relevance. Promote or demote docs by their index entries, then `Read` every doc you keep in full; the headings are a map, not the text.
4. Follow cross-references in what you read to docs the term match missed.
5. `CLAUDE.md` and `AGENTS.md` rules count even when no term matched them; read them in full unless they are already in your context.

When the scout finds no `docs/`, or a structure unlike the contract, work with what exists: note the gaps for `/debrief` and go on. Fixing the structure is not this task.

### Step 2: Identify applicable rules and conventions

List every convention, rule, pattern, or requirement from the docs that applies to this task. Group them by source file so the user can verify, and cite `file:line` for each rule: the citation is the evidence the rule was read from disk, not recalled from memory. Take the line number from a `Read` or `grep -n`, which number lines; a line counted from `cat` output is a guess. Format:

```
**Applicable rules:**

From `docs/conventions/components.md`:
- Rule 1 (docs/conventions/components.md:12)
- Rule 2 (docs/conventions/components.md:18)
  **Why:** brief rationale, carried forward verbatim from the source doc

From `CLAUDE.md`:
- Rule 3 (CLAUDE.md:40)
```

When a rule has a **Why:** line in its source, carry it forward verbatim. The rationale decides edge cases the rule does not cover, and a rule that replaced an earlier convention carries the reason not to regress to it.

If no docs exist and `CLAUDE.md` holds no conventions, recommend `/setup-docs` before proceeding. Any useful documentation, even disorganized, is enough to move forward.

### Step 3: Resolve ambiguity before planning

If a rule is ambiguous for this task, two rules pull against each other, or the task itself is unclear, ask the user now, one question at a time, with your recommended reading first. Do not guess at an ambiguous convention: the answer shapes both the doc updates and the plan.

### Step 4: Update the docs the task changes

Decide whether the task itself needs a doc change before implementation:

- Does the task introduce a new pattern that should be documented?
- Does it contradict an existing convention, and should the convention change?
- Would a gap in the docs leave future tasks unguided?

If so, propose the changes, get the user's confirmation, and make the edits, with their `_index.md` entries and the **Why:** lines the contract requires, so the plan can cite the updated conventions.

### Step 5: Propose the plan, then stop

Present the implementation plan, in plan mode where the harness offers one. The plan:

- cites the conventions and rules it follows, by `file:line`;
- names any area the conventions do not cover, and any tradeoff where following one convention strains another;
- lists the gaps, ambiguities, and missing cross-references you found that do not block this task, as candidates for `/debrief`.

Then stop: write no code until the user approves the plan.
