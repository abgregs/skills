# doc-driven-dev

AI coding skills for documentation-driven development. Keep your project docs aligned with your codebase through structured pre-task briefings, post-task debriefs, and documentation bootstrapping.

## Skills

| Skill | Description |
|-------|-------------|
| `/brief` | Pre-task briefing — discovers relevant project docs, extracts applicable rules, and proposes an aligned implementation plan before any code is written |
| `/debrief` | Post-task debrief — reviews code changes against project docs, proposes updates for new patterns or convention changes, and runs a doc health check |
| `/setup-docs` | Bootstraps or audits the `docs/` folder structure — explores the codebase, interviews you about conventions, and builds documentation incrementally |

## Install

### Via skills CLI (any supported agent)

```bash
npx skills@latest add abgregs/skills/doc-driven-dev
```

Or install individual skills:

```bash
npx skills@latest add abgregs/skills@brief
```

### Manual (Claude Code only)

Clone the skills repo and symlink this group:

```bash
git clone https://github.com/abgregs/skills.git
cd skills
./scripts/link-skills.sh doc-driven-dev
```

Or link all skill groups at once with `./scripts/link-skills.sh`.

For a single project, copy the `skills/` folders into your project's `.claude/skills/` directory.

## How it works

These skills assume a `docs/` directory structure:

```
docs/
├── _index.md              # Root TOC
├── conventions/           # How to write code
├── architecture/          # How the system works
├── requirements/          # Feature specs
└── planning/              # Active and future work
```

Each folder has an `_index.md` with entries and summaries. Files are kebab-case, single-topic, max ~150 lines.

**Start with `/setup-docs`** to bootstrap this structure for a new project, then use `/brief` before tasks and `/debrief` after.

### Recommended CLAUDE.md integration

Add this to your project's `CLAUDE.md` to make the workflow automatic:

```markdown
## Documentation-Driven Workflow

**Before any non-trivial code task:** Run `/brief` to discover relevant docs and plan.
**After any non-trivial code task:** Run `/debrief` to review changes against docs.
```

## License

MIT
