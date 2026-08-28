# Skills Repo

## Structure

- Each skill group is a top-level directory with a `README.md` and `skills/` subdirectory
- Each skill is a directory under `skills/` containing a `SKILL.md`
- All skills must be registered in `.claude-plugin/plugin.json` with repo-root-relative paths (starting with `./`)

## Skill conventions

- SKILL.md must have YAML frontmatter with `name` and `description`
- `name` must match the parent directory name (lowercase, hyphens only, max 64 chars)
- `description` should explain what the skill does AND when to trigger it (max 1024 chars)

## Script conventions (detector + judge)

- Deterministic, enumerable steps (inventories, greps, diffs, format lint,
  structural checks) live in a `scripts/` subdir of the skill and are invoked
  by SKILL.md — never re-described as instructions for the model to perform
  by hand. The model's role is judgment on the script's output (adjudicate,
  select, adjudge FIX vs JUSTIFY), plus covering what scripts can't see
  (session context, semantics, absences).
  **Why:** instruction-only checklists get pattern-matched as done without
  evidence; scripts cannot skip steps, their output doubles as the evidence
  trail, and report size scales with findings instead of corpus size.
- Reference scripts via the skill's base directory announced at load
  (`<skill-base-dir>/scripts/...`), never a hardcoded install path — the
  repo copy and `~/.claude/skills/` copy must both work.
- Scripts are report generators: no `set -e`/pipefail (a zero-match grep must
  not abort remaining sections); handle real failures explicitly.
- Editing a skill here does not update the installed copy — sync
  `~/.claude/skills/<name>/` (SKILL.md and `scripts/`) after committing.

## Adding a skill

1. Create `<group>/skills/<skill-name>/SKILL.md`
2. Add the path to `.claude-plugin/plugin.json`
3. Update the group's README skill table
4. Update the root README skill group table if it's a new group
