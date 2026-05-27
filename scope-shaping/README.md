# scope-shaping

AI coding skills that shape the scope of a task before execution. Counter-pressure to the agent's default narrow-focus behavior — surface related work, audit existing patterns, and produce a deliberately-sized plan.

## Skills

| Skill | Description |
|-------|-------------|
| `/sweep` | Identifies near-identical sibling tasks in the same domain as the stated task, audits existing patterns for consistency, and produces a tiered plan covering original + obvious + borderline siblings. Use when a task lives in a recurring pattern (notifications, data-fetching, form UX, error handling, etc.) and you want to bundle related work rather than discover it piecemeal. |

## Install

### Via skills CLI (any supported agent)

```bash
npx skills@latest add abgregs/skills/scope-shaping
```

Or install individual skills:

```bash
npx skills@latest add abgregs/skills@sweep
```

### Manual (Claude Code only)

Clone the skills repo and symlink this group via the shared linker script in the repo root.

## When to use

These skills compose with — but don't replace — documentation-driven workflows like `/brief` and `/debrief`. Run `/sweep` first to widen the scope of a narrowly-stated task, then optionally hand off to `/brief` for doc-aligned planning of the expanded scope.

Most tasks should stay narrow and not invoke these skills. Use them when:

- The stated task is one obvious instance of a recurring pattern in the codebase
- You suspect related work in the same domain would benefit from being bundled
- You want consistency-checking against existing implementations before writing new ones
