# sweep

Widens a narrowly stated task to cover its near-identical siblings in the same domain, audits the existing pattern they should all follow, and returns a tiered plan for approval. It plans only; it never writes code or files.

## Invocation

```
/sweep <task>      # or /sweep alone to use the most recent message as the task
```

Always user-invoked. Most tasks should stay narrow; reach for this when the stated task is one instance of a recurring pattern (notifications, data fetching, form errors, empty states, API shapes) and the related instances would be cheaper to do together.

## What it produces

A markdown plan in chat, in a fixed shape:

- the inferred domain
- a pattern audit: the canonical implementation, any drift, and which variant to conform to
- the original task restated
- obvious siblings (high reuse, recommended to bundle) and borderline siblings (your call), each with why it qualifies
- optional follow-ups such as drift convergence, kept separate from the immediate plan
- an ask: which items to include

After approval it hands the expanded scope back for execution, optionally via `/brief`. An empty result ("no siblings") is a valid outcome and is reported as such.

## Files

- `SKILL.md` — the five-phase workflow and its guardrails
- `examples/team-notifications.md` — a complete rendered plan with the obvious/borderline split explained

## Install

```bash
npx skills@latest add abgregs/skills@sweep
```
