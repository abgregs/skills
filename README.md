# skills

A collection of AI coding skills organized by skill group. Each group is a cohesive set of skills designed to work together.

## Skill Groups

| Group | Skills | Description |
|-------|--------|-------------|
| [doc-driven-dev](./doc-driven-dev/) | `/brief`, `/debrief`, `/setup-docs` | Keep docs aligned with code |
| [git](./git/) | `/git-commit` | Autonomous conventional commits with concise messages |
| [scope-shaping](./scope-shaping/) | `/sweep` | Widen narrowly-stated tasks to cover related work in the same domain |

## Install

### Via skills CLI (any supported agent)

Install all skills (interactive picker):

```bash
npx skills@latest add abgregs/skills
```

Install only a specific group:

```bash
npx skills@latest add abgregs/skills/doc-driven-dev
```

Install a single skill by name:

```bash
npx skills@latest add abgregs/skills@brief
```

### Manual (Claude Code only)

Clone and link all skill groups:

```bash
git clone https://github.com/abgregs/skills.git
cd skills
./scripts/link-skills.sh
```

Or link a specific group:

```bash
./scripts/link-skills.sh doc-driven-dev
```

## Structure

```
skills/
├── README.md                    # this file
├── .claude-plugin/
│   └── plugin.json              # skill registry (all groups)
├── scripts/
│   └── link-skills.sh           # per-group or all-group linking
│
├── doc-driven-dev/              # skill group
│   ├── README.md
│   └── skills/
│       ├── brief/
│       ├── debrief/
│       └── setup-docs/
│
├── git/                         # skill group
│   ├── README.md
│   └── skills/
│       ├── git-commit/
│       └── git-create-pr/
│
└── scope-shaping/               # skill group
    ├── README.md
    └── skills/
        └── sweep/
```

## Skill layout

Every skill folder follows one layout. `SKILL.md` is what the agent loads; everything else keeps it short and gives humans a way in.

```
<skill-name>/
├── SKILL.md          # required — frontmatter + the instructions the agent runs
├── README.md         # required — what it does, how to invoke it, what it produces
├── LICENSE.md        # required — MIT, Austin Gregersen
├── NOTICE.md         # optional — legal notices: third-party IP, trademarks, attributions
├── scripts/          # deterministic steps SKILL.md invokes (detector + judge, see CLAUDE.md)
├── examples/         # worked examples: sample invocations, sample output, filled templates
└── references/       # background the agent consults on demand: research, data, specs, rationale
```

**The pattern matters more than the two named folders.** `SKILL.md` carries only what the agent needs on every run; anything it reaches for sometimes — a worked example, a lookup table, research notes, collected data — moves into its own folder at the skill root and `SKILL.md` points at it. `examples/` and `references/` are the two cases that come up most often; add another folder when a skill accumulates a different kind of material.

- `examples/` and `references/` are optional but encouraged: they carry context that would otherwise bloat `SKILL.md` or the README, and they keep a skill's material organized where the next edit can find it.
- `README.md` is for people: what the skill does, how to invoke it, what it produces, and what else is in the folder. `SKILL.md` is for the agent. Do not restate one in the other.
- `NOTICE.md` appears only when there is something to notice: a skill that embeds or depends on someone else's intellectual property, a registered trademark, or material with its own attribution terms.
- `LICENSE.md` is the same MIT text in every skill, so each one stays usable when installed on its own.
- Scripts are referenced from `SKILL.md` via the skill's base directory (`<skill-base-dir>/scripts/...`), never a hardcoded install path.

## Adding a New Skill Group

1. Create a directory at the repo root with a `README.md` and `skills/` subdirectory
2. Add each skill as a folder under `skills/` using the layout above — at minimum `SKILL.md` (with `name` and `description` frontmatter), `README.md`, and `LICENSE.md`
3. Register each skill's path in `.claude-plugin/plugin.json`
4. Add the group to the table above

## Key Considerations

- **Naming collisions**: Skill names must be unique across all groups. Both the skills CLI and the link script install into flat directories, so two skills with the same name would collide. The link script warns if a collision is detected.
- **Shared utilities**: If groups ever need shared helper logic, add a top-level `shared/` directory. Defer this until actually needed.

## License

MIT — see [LICENSE.md](./LICENSE.md). Each skill also carries its own copy.
