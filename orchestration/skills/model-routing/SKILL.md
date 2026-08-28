---
name: model-routing
description: Cost-optimized routing rubric for assigning work to the right Claude model and effort level. Use when deciding which model or effort to run a task at, when spawning subagents or delegating subtasks, when authoring a Workflow/orchestration that fans out work across agents, or when the user asks "which model should I use" / "what effort level" / "route this task". Priority is cost savings without sacrificing quality.
argument-hint: "Optional — paste the task/subtasks to route; omit to just show the rubric"
---

# Model Routing — cost-optimized model + effort selection

Route each task to the **cheapest model + effort that meets the quality bar**; escalate only on observed insufficiency. Pricing/IDs below were **cached 2026-06-04** (from the `claude-api` skill catalog). Re-verify (via the `claude-api` skill or the Models API) when any concrete signal appears: today's date is ≳6 months past the cache date, the user names a model not in the table, a listed model 404s or rejects a documented param, or the user disputes a price. Absent those signals, trust the table.

## Arguments

`$ARGUMENTS` = text after `/model-routing`. **`audit` (optionally `audit <days>`) → run `python3 <skill-base-dir>/audit.py --days <N, default 7>`** (the skill's base directory is announced when it loads) and interpret the report against this rubric: explain each red flag, and call out a high "inherit-from-session" count — on an expensive session that means spawns aren't being routed at all. Otherwise: **non-empty → that text IS the task to route.** First resolve **Who plans** (next paragraph), then whoever plans: decompose into subtasks, assign each a model + effort from the table below, flag batch/cache wins; end with the cheapest coherent plan and escalation triggers. **Report by exception:** ≤6 subtasks → one-line reason per row; larger fanouts → collapse identical model+effort assignments into one row with a count (`12× read-only scouts | Haiku`), and give reasons ONLY for exceptions — gotcha-triggered picks, deviations from the nearest table row, downgrades, likely-escalation rows. Routine lookups need no justification; the forensic trail lives in the transcripts and `audit` mode, not the plan. **Empty → just show the ladder + lookup table.**

**Who plans — applies ONLY to explicit `/model-routing <task>` invocations.** If this skill loaded mid-task (you consulted it while orchestrating), skip this Who-plans block and the output format: apply the lookup table inline to the routing decision at hand — no delegation, nothing printed to the user. **Recursion guard:** if your prompt says you were spawned as the pinned planner, skip this Who-plans block only (the output format below still applies) and apply the rubric directly.

Decomposition is intelligence-sensitive — route it like any subtask, to the top of the ladder: **Fable 5 → Opus 4.8 → Sonnet 4.6** (Haiku never plans).

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

**Haiku 4.5 → Sonnet 4.6 → Opus 4.8 → Fable 5.** Default one tier and one effort notch LOWER than instinct. On agentic work, higher effort can *cut* total cost by reducing turns — measure end-to-end, not per-call.

| Model | ID | $/1M in·out | Ctx / Max out | Effort |
|---|---|---|---|---|
| Haiku 4.5 | `claude-haiku-4-5` | 1 / 5 | 200K / 64K | none (sending it errors) |
| Sonnet 4.6 | `claude-sonnet-4-6` | 3 / 15 | 1M / 64K | low–high, max — ⚠ **defaults to `high`; always set explicitly** |
| Opus 4.8 | `claude-opus-4-8` | 5 / 25 | 1M / 128K | low–xhigh, max |
| Fable 5 | `claude-fable-5` | 10 / 50 | 1M / 128K | low–xhigh, max |

Opus 4.6/4.7: same price as 4.8, superseded — only if version-pinned.

## SUBTASK → model + effort

| Subtask | Pick | Escalate to |
|---|---|---|
| Classify / extract / parse / route | Haiku 4.5 (+ Batch if offline) | Sonnet `low` |
| Summarize / chat / short content | Sonnet `low` (+ `thinking: disabled`) | Sonnet `medium` |
| Routine coding (small, well-scoped) | Sonnet `medium` | Opus `high` |
| Agentic / tool-heavy coding | Sonnet `medium` → Opus `xhigh` | Fable 5 `xhigh` |
| Hard coding / refactors / long-horizon agents | Opus 4.8 `high`→`xhigh` (full spec up front) | Fable 5 |
| Code review / bug-finding | Opus 4.8 `high`+ (report all, filter downstream) | Fable 5 — **never for security work** (gotcha 4) |
| Computer use | Sonnet `high` + adaptive | Opus 4.8 |
| Deep reasoning / correctness-critical | Opus 4.8 `max` | Fable 5 `high`/`xhigh` |
| Hardest / research-grade | Fable 5 `high`→`xhigh` | Fable 5 `max` |
| Parallel subagent fan-out | Haiku or Sonnet `low` | — |
| Anything not listed | Nearest row above; genuinely not intelligence-bound (mechanical fetch / trigger / copy / poll) → Haiku 4.5 | — |

Effort in brief: `low` subagents/simple · `medium` cost/quality balance · `high` minimum for intelligence-sensitive · `xhigh` coding/agentic sweet spot on Opus (Claude Code default) · `max` correctness>cost, overthink risk.

## Highest-impact levers & gotchas

1. **Batch API: 50% off everything** async-tolerant (most <1h, max 24h). Check FIRST — usually beats any tier debate.
2. **Prompt caching: ~0.1× on cached reads.** For repeated-context pipelines, beats a model downgrade with zero quality loss.
3. **Capability gates:** >200K context → not Haiku; >64K output → Opus/Fable only (streamed).
4. **Security/cyber & bio work: do NOT route to Fable 5** — safety classifiers refuse benign adjacent work. Use Opus 4.8, or add server-side `fallbacks` if Fable is required.
5. **Fable 5 = 2× Opus price**: only when Opus 4.8 demonstrably falls short. Turns can run minutes, thinking can't be disabled, requires 30-day retention. Nuance: Fable `low` often ≥ prior models' `xhigh` — test; can be cost-competitive on deep work.
6. **Sonnet's silent overpay:** effort defaults to `high` — set it explicitly on every Sonnet call.

## Orchestration

- Sub-agents get the ladder pick for *their* subtask, not the parent's model — scouts/mechanical passes → Haiku or Sonnet `low`. In `Workflow` scripts: per-`agent()` `opts.model` / `opts.effort`.
- **Always pass `model:` explicitly on routed spawns — even when the pick equals the session model.** Identical behavior, but it fingerprints the decision in transcripts: explicit = routed, absent = unconsidered. The audit's decision-rate metric depends on this.
- Keep the orchestrator on one model (preserves prompt cache); delegate the cheap work rather than switching the main loop mid-session.
- **Know your levers per context.** API pipelines (user-built code): all levers — model, effort, Batch, caching. In-session `Workflow agent()`: model + effort. In-session `Agent` tool: **model only** (effort inherits the session — don't promise effort assignments an `Agent` spawn can't honor). Batch/caching never apply to in-session spawns; flag them only for API-pipeline subtasks.

## Effort Parameter Caveat

When routing subagents in Workflow scripts, you can pass an `effort` parameter (e.g., `agent(prompt, {model: "claude-opus-4-8", effort: "high"})`). **However, there is currently no audit trail in the response metadata.** The API does not echo back which effort level was actually used by the subagent — you cannot verify post-execution whether your `effort` assignment was honored or what impact it had relative to other factors (thinking depth, task complexity, etc.).

This is a known limitation. The rubric includes `effort` assignments as a desirable optimization layer, but accept that you cannot audit whether subagents actually used the effort level you specified. For now, treat effort assignments as intent — log them yourself if correctness or cost auditing is critical, and understand that verification is manual correlation of token counts against your logged requests, not a reliable inference from response data.

**This caveat does NOT apply to effort on the main session** — if you control the session model directly, effort works as intended and you observe the token cost tradeoff in the response.

## Honesty

Pricing, batch discount, and cache multipliers are exact (published). Task-fit and effort cells are directional Anthropic guidance — no public model×effort×task benchmark exists; sweep `medium`/`high`/`xhigh` on your own evals per route.
