# skills

A collection of AI coding skills organized by skill group. Each group is a cohesive set of skills designed to work together.

## Skill Groups

| Group | Skills | Description |
|-------|--------|-------------|
| [doc-driven-dev](./doc-driven-dev/) | `/brief`, `/debrief`, `/setup-docs` | Keep docs aligned with code |

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
│       ├── brief/SKILL.md
│       ├── debrief/SKILL.md
│       └── setup-docs/SKILL.md
│
└── <another-group>/             # future skill groups
    ├── README.md
    └── skills/
        └── <skill>/SKILL.md
```

## Adding a New Skill Group

1. Create a directory at the repo root with a `README.md` and `skills/` subdirectory
2. Add each skill as a folder under `skills/` containing a `SKILL.md` (with `name` and `description` frontmatter)
3. Register each skill's path in `.claude-plugin/plugin.json`
4. Add the group to the table above

## Key Considerations

- **Naming collisions**: Skill names must be unique across all groups. Both the skills CLI and the link script install into flat directories, so two skills with the same name would collide. The link script warns if a collision is detected.
- **Shared utilities**: If groups ever need shared helper logic, add a top-level `shared/` directory. Defer this until actually needed.

## License

MIT
