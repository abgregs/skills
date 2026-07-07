# orchestration

AI coding skills for deciding how work gets delegated across agents and models. When a task fans out into subtasks — subagents, Workflow scripts, API pipelines — these skills route each piece to the right place instead of running everything on the session's default.

## Skills

| Skill | Description |
|-------|-------------|
| `/model-routing` | Cost-optimized routing rubric for assigning work to the right Claude model and effort level. Use when deciding which model or effort to run a task at, when spawning subagents or delegating subtasks, or when authoring a Workflow that fans out work across agents. Includes an `audit` mode that reads Claude Code transcripts to report which models subagents actually used versus the rubric. Priority is cost savings without sacrificing quality. |

## Install

### Via skills CLI (any supported agent)

```bash
npx skills@latest add abgregs/skills/orchestration
```

Or install individual skills:

```bash
npx skills@latest add abgregs/skills@model-routing
```

### Manual (Claude Code only)

Clone the skills repo and symlink this group via the shared linker script in the repo root.

> **Note:** `/model-routing` references its own install path (`~/.claude/skills/model-routing/`) for the rubric and `audit.py`, so the skill directory name must stay `model-routing` for those references to resolve.

## When to use

- Manually invoke `/model-routing <task>` to get a decomposed plan with a model + effort assignment per subtask
- Let the model consult it mid-task whenever it's about to spawn subagents or author a Workflow, so routed spawns always pin an appropriate model
- Run `/model-routing audit` periodically to check that spawns are actually being routed, not silently inheriting the session model
