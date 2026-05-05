# Skills Repo

## Structure

- Each skill group is a top-level directory with a `README.md` and `skills/` subdirectory
- Each skill is a directory under `skills/` containing a `SKILL.md`
- All skills must be registered in `.claude-plugin/plugin.json` with repo-root-relative paths (starting with `./`)

## Skill conventions

- SKILL.md must have YAML frontmatter with `name` and `description`
- `name` must match the parent directory name (lowercase, hyphens only, max 64 chars)
- `description` should explain what the skill does AND when to trigger it (max 1024 chars)

## Adding a skill

1. Create `<group>/skills/<skill-name>/SKILL.md`
2. Add the path to `.claude-plugin/plugin.json`
3. Update the group's README skill table
4. Update the root README skill group table if it's a new group
