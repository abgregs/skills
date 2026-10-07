# git-commit

Writes conventional commit messages and executes the commits, without approval prompts. Messages carry the change and never its provenance: no co-author trailers, tool names, or session links.

## Invocation

```
/git-commit            # commit whatever is in the working tree
/git-commit --amend    # interactively reword or extend the last commit
```

The mode follows the state of the tree:

| Tree state | Mode | Result |
|---|---|---|
| Staged changes exist | single | One commit of exactly the staged files |
| Only unstaged changes | grouped | Several commits, split by intent, foundational work first |
| `--amend` | amend | Interactive: message only, or fold in staged changes |

Untracked files are never touched. Stage specific files first to control exactly what one commit contains.

## What it produces

- Subjects in `type(scope): description` form, under 72 characters
- A body only when bullets add information the diff does not state; 2–4 bullets, 8 at most
- Each commit printed with its file list before it runs, and `git log -1` after

## Files

- `SKILL.md` — the workflow the agent follows
- `scripts/commit-preflight.sh` — the detector: reports mode, recent subjects, and stats; `--lint <file>` gates every message before `git commit -F`
- `examples/commit-messages.md` — messages in each shape, plus ones the lint rejects

## Requirements

`git` and `bash`. No network access. Pre-commit hooks run normally; the skill never passes `--no-verify` or force-pushes.

## Install

```bash
npx skills@latest add abgregs/skills@git-commit
```
