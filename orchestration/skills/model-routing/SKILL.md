---
name: model-routing
description: Cost-optimized routing rubric for assigning work to the right Claude model and effort level. Use when deciding which model or effort to run a task at, when spawning subagents or delegating subtasks, when authoring a Workflow/orchestration that fans out work across agents, or when the user asks "which model should I use" / "what effort level" / "route this task". Priority is cost savings without sacrificing quality.
argument-hint: "Optional — paste the task/subtasks to route; omit to just show the rubric"
---

# Model Routing — cost-optimized model + effort selection

Route each task to the **cheapest model + effort that meets the quality bar**; escalate only on observed insufficiency. Pricing/IDs below were **re-verified 2026-08-28** against the `claude-api` skill catalog (catalog cache 2026-06-24; added Sonnet 5 and Opus 5). Re-verify (via the `claude-api` skill or the Models API) when any concrete signal appears: today's date is ≳6 months past the verification date, the user names a model not in the table, a listed model 404s or rejects a documented param, or the user disputes a price. Absent those signals, trust the table.

## Arguments

`$ARGUMENTS` = text after `/model-routing`. **`audit` (optionally `audit <days>`) → run `python3 <skill-base-dir>/audit.py --days <N, default 7>`** (the skill's base directory is announced when it loads) and interpret the report against this rubric: explain each red flag, and call out a high "inherit-from-session" count — on an expensive session that means spawns aren't being routed at all. Otherwise: **non-empty → that text IS the task to route.** First resolve **Who plans** (next paragraph), then whoever plans: decompose into subtasks, assign each a model + effort from the table below, flag batch/cache wins; end with the cheapest coherent plan and escalation triggers. **Report by exception:** ≤6 subtasks → one-line reason per row; larger fanouts → collapse identical model+effort assignments into one row with a count (`12× read-only scouts | Haiku`), and give reasons ONLY for exceptions — gotcha-triggered picks, deviations from the nearest table row, downgrades, likely-escalation rows. Routine lookups need no justification; the forensic trail lives in the transcripts and `audit` mode, not the plan. **Empty → just show the ladder + lookup table.**

**Who plans — applies ONLY to explicit `/model-routing <task>` invocations.** If this skill loaded mid-task (you consulted it while orchestrating), skip this Who-plans block and the output format: apply the lookup table inline to the routing decision at hand — no delegation, nothing printed to the user. **Recursion guard:** if your prompt says you were spawned as the pinned planner, skip this Who-plans block only (the output format below still applies) and apply the rubric directly.

Decomposition is intelligence-sensitive — route it like any subtask, to the top of the ladder: **Fable 5 → Opus 5 → Sonnet 5** (Haiku never plans).

1. Session model is Fable 5 (or the highest tier you know to be available) → plan in-context (no subagent overhead, keeps conversation context).
2. Otherwise → spawn a subagent pinned to the highest tier above the session model (`Agent` tool, `model: "fable"` / `"opus"` / `"sonnet"`). Subagents start blank — nothing passes automatically, so the prompt you author must carry all three: (a) the task (`$ARGUMENTS`), (b) any session context the plan needs, and (c) the rubric — by instructing it to `Read` this skill's `SKILL.md` at the base directory announced when the skill loaded (substitute the actual absolute path into the subagent prompt) and apply the lookup table, noting it is the pinned planner (don't paste the rubric; the file is the single source of truth). Relay its plan.
3. Spawn fails (no access) → step down the ladder; note the downgrade in the output. **Floor rule:** if the step-down reaches the session model's own tier, plan in-context — a same-tier subagent costs the same with less context.

A skill cannot switch the session's own model — pinning happens via delegation, never `/model`. The plan is one bounded call, cheap even on Fable relative to misrouted execution. Output is a **plan, not execution** — delegation of the actual subtasks happens afterward, on request, via the Orchestration section.

```
Task: <one-line restatement>
| Subtask | Model | Effort | Batch? | Why |
Cheapest plan: …   Orthogonal savings: …   Escalate if: …
```

## Ladder & models

**Haiku 4.5 → Sonnet 5 → Opus 5 → Fable 5.** Default one tier and one effort notch LOWER than instinct. On agentic work, higher effort can *cut* total cost by reducing turns — measure end-to-end, not per-call. Note the mid-tier repricing: Sonnet 5 is 2× Haiku (was 3× on Sonnet 4.6), so Sonnet `low` competes harder as the classify/extract escalation target.

| Model | ID | $/1M in·out | Ctx / Max out | Effort |
|---|---|---|---|---|
| Haiku 4.5 | `claude-haiku-4-5` | 1 / 5 | 200K / 64K | none (sending it errors) |
| Sonnet 5 | `claude-sonnet-5` | 2 / 10 | 1M / 128K | low–xhigh, max — ⚠ **defaults to `high`; always set explicitly** |
| Opus 5 | `claude-opus-5` | 5 / 25 | 1M / 128K | low–xhigh, max (thinking on by default; refusal classifiers — gotcha 4) |
| Fable 5 | `claude-fable-5` | 10 / 50 | 1M / 128K | low–xhigh, max |

Superseded — version-pinned use only: Opus 4.6/4.7/4.8 (same 5/25; **4.8 is also the security-work escape hatch, gotcha 4**) and Sonnet 4.6 (3/15 — costs MORE than its successor; never route new work there).

## SUBTASK → model + effort

| Subtask | Pick | Escalate to |
|---|---|---|
| Classify / extract / parse / route | Haiku 4.5 (+ Batch if offline) | Sonnet `low` |
| Summarize / chat / short content | Sonnet `low` (+ `thinking: disabled`) | Sonnet `medium` |
| Routine coding (small, well-scoped) | Sonnet `medium` | Opus `high` |
| Agentic / tool-heavy coding | Sonnet `medium` → Opus `xhigh` | Fable 5 `xhigh` |
| Hard coding / refactors / long-horizon agents | Opus 5 `high`→`xhigh` (full spec up front) | Fable 5 |
| Code review / bug-finding | Opus 5 `high`+ (report all, filter downstream) | Fable 5 — **security work → Opus 4.8 instead** (gotcha 4) |
| Computer use | Sonnet `high` + adaptive | Opus 5 |
| Deep reasoning / correctness-critical | Opus 5 `max` | Fable 5 `high`/`xhigh` |
| Hardest / research-grade | Fable 5 `high`→`xhigh` | Fable 5 `max` |
| Parallel subagent fan-out | Haiku or Sonnet `low` | — |
| Anything not listed | Nearest row above; genuinely not intelligence-bound (mechanical fetch / trigger / copy / poll) → Haiku 4.5 | — |

Effort in brief: `low` subagents/simple · `medium` cost/quality balance · `high` minimum for intelligence-sensitive · `xhigh` coding/agentic sweet spot on Opus (Claude Code default) · `max` correctness>cost, overthink risk.

## Highest-impact levers & gotchas

1. **Batch API: 50% off everything** async-tolerant (most <1h, max 24h). Check FIRST — usually beats any tier debate.
2. **Prompt caching: ~0.1× on cached reads.** For repeated-context pipelines, beats a model downgrade with zero quality loss.
3. **Capability gates:** >200K context or >64K output → not Haiku (Sonnet 5, Opus 5, and Fable 5 all do 1M ctx / 128K out, streamed).
4. **Security/cyber & bio work: do NOT route to Fable 5 *or* Opus 5** — both carry refusal classifiers that decline benign adjacent work. Use Opus 4.8 (the escape hatch that keeps 5-tier pricing), or add the server-side `fallbacks` parameter if Fable/Opus 5 is required — current guidance is to include `fallbacks` by default on Fable 5 and Opus 5 pipelines anyway.
5. **Fable 5 = 2× Opus price**: only when Opus 5 demonstrably falls short. Turns can run minutes, thinking can't be disabled, requires 30-day retention. Nuance: Fable `low` often ≥ prior models' `xhigh` — test; can be cost-competitive on deep work.
6. **Sonnet's silent overpay:** effort defaults to `high` — set it explicitly on every Sonnet call (applies to Sonnet 5 unchanged).
7. **Latency levers, priced:** fast mode (Opus 5/4.8 only, Claude API only) runs ~2.5× output speed at 10/50 — pay for speed only where a human is waiting. **Priority Tier excludes Opus 5 and Sonnet 5** (Fable 5 and Opus 4.8 are covered) — check before routing latency-SLA pipelines to the 5-tier.

## Orchestration

- Sub-agents get the ladder pick for *their* subtask, not the parent's model — scouts/mechanical passes → Haiku or Sonnet `low`. In `Workflow` scripts: per-`agent()` `opts.model` / `opts.effort`.
- **Always pass `model:` explicitly on routed spawns — even when the pick equals the session model.** Identical behavior, but it fingerprints the decision in transcripts: explicit = routed, absent = unconsidered. The audit's decision-rate metric depends on this.
- Keep the orchestrator on one model (preserves prompt cache); delegate the cheap work rather than switching the main loop mid-session.
- **Know your levers per context.** API pipelines (user-built code): all levers — model, effort, Batch, caching. In-session `Workflow agent()`: model + effort. In-session `Agent` tool: **model only** (effort inherits the session — don't promise effort assignments an `Agent` spawn can't honor). Batch/caching never apply to in-session spawns; flag them only for API-pipeline subtasks.

## Effort Parameter Caveat

When routing subagents in Workflow scripts, you can pass an `effort` parameter (e.g., `agent(prompt, {model: "claude-opus-5", effort: "high"})`). **However, there is currently no audit trail in the response metadata.** The API does not echo back which effort level was actually used by the subagent — you cannot verify post-execution whether your `effort` assignment was honored or what impact it had relative to other factors (thinking depth, task complexity, etc.).

This is a known limitation. The rubric includes `effort` assignments as a desirable optimization layer, but accept that you cannot audit whether subagents actually used the effort level you specified. For now, treat effort assignments as intent — log them yourself if correctness or cost auditing is critical, and understand that verification is manual correlation of token counts against your logged requests, not a reliable inference from response data.

**This caveat does NOT apply to effort on the main session** — if you control the session model directly, effort works as intended and you observe the token cost tradeoff in the response.

## Honesty

Pricing, batch discount, and cache multipliers are exact (published). Task-fit and effort cells are directional Anthropic guidance — no public model×effort×task benchmark exists; sweep `medium`/`high`/`xhigh` on your own evals per route.
