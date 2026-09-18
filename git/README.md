# git

AI coding skills for git hygiene. Well-formed conventional commits, clean history, and reviewable pull requests without manual message-writing or babysitting the staging area.

## Skills

| Skill | Description |
|-------|-------------|
| `/git-commit` | Generates conventional commit messages and executes commits autonomously. Commits staged changes as a single commit, splits a dirty working tree into logically grouped commits, and supports an interactive `--amend` mode. Enforces concise message bodies, safe hook-failure handling, and never force-pushes or bypasses hooks. |
| `/git-create-pr` | Pushes the current branch and opens or updates a pull request through `gh`, with the body written from the merge-base diff. A read-only preflight resolves the base branch, push state, existing PR, the repo's own PR template and title style; a body lint gates the summary before it ships. Never force-pushes, bypasses hooks, or merges. |

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
- Invoke `/git-create-pr` once the branch is committed — it pushes and opens the PR, or rewrites the body of the PR already open for the branch
- Pass a base branch (`/git-create-pr develop`) only to override the repo default, which it resolves on its own
