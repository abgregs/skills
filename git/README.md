# git

AI coding skills for git hygiene. Well-formed conventional commits and clean history without manual message-writing or babysitting the staging area.

## Skills

| Skill | Description |
|-------|-------------|
| `/git-commit` | Generates conventional commit messages and executes commits autonomously. Commits staged changes as a single commit, splits a dirty working tree into logically grouped commits, and supports an interactive `--amend` mode. Enforces concise message bodies, safe hook-failure handling, and never force-pushes or bypasses hooks. |

## Install

### Via skills CLI (any supported agent)

```bash
npx skills@latest add abgregs/skills/git
```

Or install individual skills:

```bash
npx skills@latest add abgregs/skills@git-commit
```

### Manual (Claude Code only)

Clone the skills repo and symlink this group via the shared linker script in the repo root.

## When to use

- Invoke `/git-commit` whenever committing — it detects the right mode from the state of the working tree
- Stage specific files first to control exactly what goes in the commit (single mode); leave everything unstaged to let it group related changes into separate commits
- Use `/git-commit --amend` to interactively reword the last commit or fold newly staged changes into it
