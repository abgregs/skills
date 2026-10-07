---
name: sweep
description: Scope-expansion skill. Identifies near-identical sibling tasks in the same domain as the stated task, audits existing patterns for consistency, and produces an expanded plan covering original + obvious + borderline siblings. Use when a stated task lives in a recurring pattern (notifications, data-fetching, form UX, error handling, API shapes, etc.) and you want to bundle related work rather than discover it piecemeal. Acts as a deliberate counter-pressure to the agent's default narrow-scope focus. Always user-invoked; never auto-applies.
---

You are about to take a narrowly-stated task and deliberately widen its scope to cover near-identical work within the same domain. This skill exists because coding agents default to focusing only on what the user typed — which is usually correct, but occasionally misses obvious extensions that the user would want bundled.

**Task / context:** $ARGUMENTS

If the argument is empty, infer the task from the user's most recent message in the conversation.

## What this skill does

1. Infers the domain of the stated task
2. Searches the codebase for other addressable areas in that same domain (siblings)
3. Audits existing patterns for the domain to ensure consistency
4. Produces a tiered plan (original + obvious siblings + borderline siblings + optional drift convergence)
5. Hands off to the agent after user approval — does NOT execute code itself

## Workflow

### Phase 1 — Infer the domain

Read the task. Without asking the user, infer the domain category by examining the task's surface. The domain is the recurring pattern or concern the task lives in. Examples:

- "Add notification + email when X happens" → **User-facing communication for state-change events** (in-app + email, recipient = affected user or relevant party)
- "Optimize caching for the X dashboard route" → **Data-fetching + caching across analogous routes**
- "Standardize error messaging on the X form" → **Form-error UX across analogous forms**
- "Refactor the X API endpoint to return Y shape" → **API endpoint shape consistency**
- "Add empty state to the X view" → **Empty-state UX across analogous views**

If the task doesn't clearly map to a recurring pattern (one-off feature, isolated bug fix, etc.), say so plainly: "This task doesn't appear to live in a recurring pattern. /sweep wouldn't expand scope meaningfully here. Recommend running /brief or proceeding directly." Then exit.

### Phase 2 — Discover siblings

Search the codebase for other actions, events, routes, components, or other addressable code locations that live in the same inferred domain. Use `grep`, `Glob`, and targeted file reads. For each candidate, capture:

- **Identifier**: file path + symbol (e.g. `src/app/_actions/team-actions.ts → leaveTeamImpl`)
- **Why it's a sibling**: the shared shape with the original task
- **Current state**: does the treatment already exist for this sibling? Partially? Not at all?
- **Confidence rating**:
  - **Obvious**: high reuse, near-identical workflow, same UX expectation
  - **Borderline**: plausible but workflow diverges in non-trivial ways (different recipient, different trigger condition, different UX intent)

**High-reuse requirement**: each suggested sibling must reuse a meaningful portion of the original task's pattern. Low-reuse "siblings" are scope creep dressed as expansion — discard them.

**Cap**: surface at most ~5-7 sibling candidates across both tiers. If more are found, summarize the rest as "additional candidates found, narrow the domain hint to focus" with a count.

### Phase 3 — Audit existing patterns

The audit scope matches the domain inferred in Phase 1:

- UI/communication tasks → audit existing templates, components, copy, messaging tone, spacing/styling conventions
- Backend / data-fetching / caching tasks → audit existing query patterns, caching strategies, action shapes, side-effect handling
- Cross-cutting / structural tasks → audit existing architectural patterns in the same layer

Read enough of the relevant files to identify:

- **Canonical pattern in use**: what does the existing implementation look like? List the key files and the patterns they share.
- **Drift observed**: do multiple patterns exist for the same purpose? Are they inconsistent?
- **Conformance recommendation**: should the new work follow the canonical pattern? If drift exists, which variant is most-recent or most-tested and should be canonical going forward?

**Drift handling rule**: when multiple patterns exist for the same purpose, recommend the **most-recent or most-tested** variant as canonical. Surface drift explicitly; propose convergence onto the canonical as **optional follow-up work**, separate from the immediate plan. Do not silently average across patterns.

### Phase 4 — Compose and present the plan

Render the expanded plan as structured markdown in chat (no files). Use this template literally — the section structure is part of the skill's value:

```
## /sweep results for: "<original task as stated>"

### Inferred domain
<one-sentence: what surface area this belongs to>

### Pattern audit
- Canonical pattern: <name + key file refs> (or "none established yet — propose this work establishes it")
- Drift observed: <none / brief description of variants found>
- Recommendation: <conform to canonical / converge variants on most-recent-or-most-tested / propose new canonical>

### Original task
<exact restatement of the user's stated task>

### Obvious siblings (recommended to bundle)
- [ ] <sibling name> — <why it's obvious, what's reused>
- [ ] <sibling name> — <why it's obvious, what's reused>

### Borderline siblings (your call)
- [ ] <sibling name> — <reason it's borderline, what the workflow divergence is>
- [ ] <sibling name> — <reason it's borderline>

### Optional follow-ups
- <drift convergence as separate work, if relevant>
- <other related observations worth flagging that aren't /sweep-scope expansions>

### Ask
Confirm which obvious and borderline items to include. After approval I'll hand off the expanded scope for execution (optionally via /brief for doc-aligned planning).
```

If no siblings are found, render an abbreviated plan stating so explicitly. Never fabricate siblings.

### Phase 5 — Hand off after approval

After the user confirms which items to include:
1. Acknowledge the final scope concisely
2. Recommend whether to run `/brief` next (yes if the project uses doc-driven-dev conventions or if the pattern audit identified specific docs to consult; no if the work is straightforward and the user prefers to proceed directly)
3. Exit the skill

The agent then proceeds with the expanded scope. This skill does NOT execute code itself.

## Guardrails

- **Strict same-domain rule**: never suggest cross-domain extensions (e.g. "while adding notifications, also add analytics events"). If a candidate sibling is in a different domain, omit it entirely. Don't even surface it as a follow-up.
- **High-reuse requirement** (restated): each sibling must reuse a meaningful portion of the original task. If a sibling would essentially be a from-scratch implementation that happens to share a domain label, it's not a sibling — it's a separate task.
- **Stopping point on workflow divergence**: when a candidate sibling diverges enough in workflow shape to warrant its own design conversation, do not bundle it. Surface as "additional candidate — separate task recommended."
- **No code action**: the skill plans only. Never writes or modifies code. Hands off the expanded scope for the agent to execute.
- **No file output**: produces a markdown plan in chat. Does not auto-create todo docs, plan files, or any persistent artifacts. The user can re-invoke `/sweep` later to re-discover deferred siblings.
- **Empty result honesty**: if no siblings exist, say so explicitly. Proceeding with the original task as stated is the right answer in that case.

## What /sweep is NOT

- Not a refactoring tool — doesn't analyze code quality or propose improvements unrelated to the original task
- Not a full architectural review — sweeps the domain inferred from the task, not the entire codebase
- Not always-on — explicitly user-invoked; most tasks should stay narrow
- Not a replacement for `/brief` — composes with it (sweep widens scope; brief aligns to docs)
- Not a sibling-finding lottery — high-confidence reuse is the threshold; low-confidence guesses are scope creep

## Worked example

When unsure how full a rendered plan should be, or how to word reuse and divergence for a sibling, read `<skill-base-dir>/examples/team-notifications.md` — a complete plan for a team-membership notification task, with the obvious/borderline split explained.

## Important

- Do NOT execute any code work during this skill — planning only
- Do NOT modify any files during this skill (no todos, no plans, no code)
- Do NOT propose cross-domain extensions
- Do NOT fabricate siblings to justify the skill being invoked — empty result is a valid outcome
- Address the user, not the agent, in the rendered plan output (the plan is for the user to review)
