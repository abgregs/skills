# debrief

Post-task debrief. Reviews the code changes just made against the project docs, proposes and applies the doc updates they require, and runs a health check so the docs stay aligned with the codebase.

## Invocation

```
/debrief                   # review the change since the last debrief, or since the branch point
/debrief <axis or notes>   # name the cross-cutting axis to audit, a range such as origin/main..HEAD, or other context
```

Run it after any non-trivial code task. Doc edits are confirmed with you before they are made; nothing is deleted without approval.

## What it produces

- A classification of each proposed update: new rule, replacement, clarification, or removal, with the **Why:** lines the docs contract requires
- The doc edits themselves, with `_index.md` entries kept current and files split at the contract's 150-line limit
- A health check in which every finding has an ID and a verdict: retired terms, referrers of changed docs, stale stamps, and structure faults in the docs the change touched (dead links, orphans, folders with no index, entries with no summary, oversized files), each judged FIX or JUSTIFY, plus the reads for semantic staleness. Structure faults elsewhere are listed as standing, without a verdict, and feed one or two small structural fixes per run
- One cross-cutting axis audited per run, to catch rules that are individually correct but compose badly across docs
- An adversarial second pass before the summary, so a "double-check" follow-up finds nothing

## The detector's interface

`scripts/doc-sweep.sh` has four calls:

| Call | Does | Exit |
|---|---|---|
| `--scope [--base <rev>]` | picks the base and prints it with the commits, change stat, and untracked files since | 0; 1 outside git or for a bad `<rev>`; 3 nothing changed since the base; 4 no reliable base, so the agent asks for a range |
| no flag | the sweep: a digest under 20 KB (`DOC_SWEEP_BUDGET`), findings first, each under an ID that stays the same across reruns; the full report at `.git/doc-sweep-report.txt` | 0; 1 with no `docs/`, `CLAUDE.md`, or `AGENTS.md` (`DOC_SWEEP_DIR` points elsewhere); with only the root files, it sweeps those |
| `--verdicts [- \| <file>]` | adds `<ID> FIX\|JUSTIFY <reason>` lines (from stdin with `-`) to the debrief's verdicts, then refuses until every finding raised by any sweep of this debrief has one | 0; 2 names each unjudged finding; 3 no sweep yet |
| `--mark` | records HEAD as the next debrief's base, and ends the debrief | 0; 2 refused while a finding of this debrief has no verdict; `--accept-unjudged`, the user's override, marks anyway |

The base is, in order: `--base`; the base `--scope` picked for this debrief; the last debrief's mark when it is an ancestor of HEAD; the merge-base with the default branch, when the branch has commits past it; HEAD, when the only changes are uncommitted; `HEAD~5`, which `--scope` refuses as a guess. Step 1 and the sweep therefore read the same change, and a branch in a fresh worktree is compared from its branch point rather than its last five commits.

The change is everything since the base: commits, staged and unstaged edits, and untracked files. `git diff` leaves untracked files out, so `--scope` lists them and the agent reads each one. A debrief needs no commit first. The mark records HEAD, so work still uncommitted when the debrief marks shows up again in the next one.

**State.** Everything lives in the git directory, never the working tree, so there is nothing to `.gitignore`. The mark is `doc-sweep-mark` in the common git dir, shared by every worktree; the base, the findings, the verdicts, and the full report are per worktree. `--scope` starts a debrief and clears the findings and verdicts. Each sweep adds its findings to the debrief's, so a finding that a later sweep no longer shows, fixed or hidden by an edit, still needs its verdict. `--mark` ends the debrief and clears the base, findings, and verdicts. A mark left by the earlier version at `.claude/last-doc-sweep` is still read, and `--mark` says when it can be deleted.

**What the sweep reads.** Retired terms come from removed doc lines, `CLAUDE.md` and `AGENTS.md` included, and from the code diff: a string literal or a snake_case, kebab-case, or camelCase name the code dropped, which no added line still uses, is a term, so a change to code alone is still found when a doc names what it dropped. A name the code moved to another file is not dropped. Acronyms of three letters or more count, and a term under four letters matches only as a whole word. Referrers include the docs that still name a doc the change renamed or deleted. Text from a **Why:** to the end of its line counts neither way: it records what a rule replaced.

**What it cannot see.** A change of behavior with no dropped name, such as a token's lifetime going from 30 days to 15 minutes, a rule that was never written down, and a doc that describes the old behavior in other words. Step 2's reads and Step 5's blind-spot checks are there for these.

## Files

- `SKILL.md` — the six-step workflow, opening with the docs contract it shares with `brief` and `setup-docs`
- `scripts/doc-sweep.sh` — the detector and the verdict check
- `examples/doc-update-proposal.md` — a filled proposal for a convention replacement

The repo's `scripts/test-doc-driven-dev.sh` tests the detector, and `evidence/` holds recorded runs.

## Expected project layout

A `docs/` folder with `_index.md` files per category, as bootstrapped by `/setup-docs`; falls back to listing `docs/**/*.md` when no index exists.

## Install

```bash
npx skills@latest add abgregs/skills@debrief
```
