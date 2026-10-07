# debrief

Post-task debrief. Reviews the code changes just made against the project docs, proposes and applies the doc updates they require, and runs a health check so the docs stay aligned with the codebase.

## Invocation

```
/debrief                   # review the current diff
/debrief <axis or notes>   # name the cross-cutting axis to audit, or add context
```

Run it after any non-trivial code task. Doc edits are confirmed with you before they are made; nothing is deleted without approval.

## What it produces

- A classification of each proposed update: new rule, replacement, clarification, or removal, with a mandatory **Why:** line on replacements
- The doc edits themselves, with `_index.md` entries kept current and files split at ~150 lines
- A health check whose every item cites its evidence: structural checks (orphans, dead links, missing summaries), retired-term hits adjudicated FIX or JUSTIFY, and a read for semantic staleness
- One cross-cutting axis audited per run, to catch rules that are individually correct but compose badly across docs
- An adversarial second pass before the summary, so a "double-check" follow-up finds nothing

## Files

- `SKILL.md` — the six-step workflow
- `scripts/doc-sweep.sh` — the detector: retired-term candidates from the diff since the last sweep, referrers of changed docs, freshness stamps, and structural checks; `--mark` records where the next sweep starts
- `examples/doc-update-proposal.md` — a filled proposal for a convention replacement

## Expected project layout

A `docs/` folder with `_index.md` files per category, as bootstrapped by `/setup-docs`; falls back to scanning `docs/**/*.md` when no index exists.

## Install

```bash
npx skills@latest add abgregs/skills@debrief
```
