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

## Stances

Installing the skill opts into two opinions. Both are enforced by the lint, so they are worth knowing before the first run.

- **Subject format is a default, not an override.** Subjects are `type(scope): description` when the repo has no convention of its own. When the preflight finds a repo-owned enforcer (a commitlint config, a `commit-msg` hook, gitlint, lefthook or pre-commit commit-message hooks, or `commit.template`), the repo's format wins: the skill writes subjects in the shape the repo's history and config show, and the lint skips its format checks. The repo's hook stays the judge; if it rejects a message, the skill shows the output, rewrites the subject to the hook's rule, and retries once.
- **Messages carry the change, never its provenance.** No co-author trailer, tool or model name, session link, or robot emoji, even when the session's harness or instructions ask for one. A commit message records what changed in the code; who or what typed it is a policy question that belongs in the repo's contributing docs, not in every message. If your team requires an attribution trailer, this skill is the wrong fit as written: fork it and remove the provenance wall from `SKILL.md` and the `--lint` block, rather than trying to argue the agent past it.

## Files

- `SKILL.md` — the workflow the agent follows
- `scripts/commit-preflight.sh` — the detector: reports mode, recent subjects, and stats; `--lint <file>` gates every message before `git commit -F`
- `examples/commit-messages.md` — messages in each shape, plus ones the lint rejects
- `evidence/` — recorded runs against a bare agent on the same input, one case per file, with the method to rerun them

## Requirements

`git` and `bash`. No network access. Pre-commit hooks run normally; the skill never passes `--no-verify` or force-pushes.

## Install

```bash
npx skills@latest add abgregs/skills@git-commit
```
