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
| Only unstaged changes | grouped | Several commits, each able to stand alone: changes that cannot build or pass apart, or that exist only for each other, such as a change and the tests and docs that cover it, share a commit; independent ones split by type and outcome, and each lands after the commits it needs. When the split is a close call, such as tests filling gaps across several suites, they stay one commit unless reviewing them together would take about an hour or more |
| `--amend` | amend | Interactive: message only, or fold in staged changes |

Untracked files are never touched; mark a new file with `git add -N` to include it. Stage specific files first to control exactly what one commit contains. Grouped mode asks no questions and stages nothing itself; each commit names its files to the gate. When one source file holds pieces of two changes, it commits them together, since a split by file would leave the earlier commit incomplete. Its summary gives each commit's reason and says which changes a shared file joined.

## What it produces

- Subjects in `type(scope): description` form, under 72 characters
- A body only when bullets add information the diff does not state; 1–4 bullets, 6 at most
- A first `- Why:` bullet when the change has a cause from outside the code (a trigger, an environment, an outside requirement, a measured figure); most commits skip it, and `docs`, `chore`, and `test` commits never carry one
- Each commit printed with its file list before it runs, and `git log -1` after

## Stances

Installing the skill opts into two opinions. Both are enforced by the lint, so they are worth knowing before the first run.

- **Subject format is a default, not an override.** Subjects are `type(scope): description` when the repo has no convention of its own. When the preflight finds a repo-owned enforcer (a commitlint config, a `commit-msg` hook, gitlint, lefthook or pre-commit commit-message hooks, or `commit.template`), the repo's format wins: the skill writes subjects in the shape the repo's history and config show, and the lint skips its format checks. The repo's hook stays the judge; if it rejects a message, the skill shows the output, rewrites the subject to the hook's rule, and retries once.
- **Messages carry the change, never its provenance.** No co-author trailer, tool or model name, session link, or robot emoji, even when the session's harness or instructions ask for one. A commit message records what changed in the code; who or what typed it is a policy question that belongs in the repo's contributing docs, not in every message. If your team requires an attribution trailer, this skill is the wrong fit as written: fork it and remove the provenance wall from `SKILL.md` and the `--lint` block, rather than trying to argue the agent past it.

## Files

- `SKILL.md` — the workflow the agent follows
- `scripts/commit-preflight.sh` — the detector: reports mode, recent subjects, and stats; `--commit <file> -- <paths>` lints each message and commits exactly those paths only on a clean result, so a failed or warned message is never committed and a stopped commit leaves nothing staged; `--size <paths>` counts the changed lines a reviewer reads, for the close grouping calls
- `examples/commit-messages.md` — messages in each shape, plus ones the lint rejects
- `evidence/` — recorded runs, most against a bare agent on the same input, one case per file, with the method to rerun them, and a history of the earlier runs that shaped the rules

## Requirements

`git` and `bash`. No network access. Pre-commit hooks run normally; the skill never passes `--no-verify` or force-pushes.

## Install

```bash
npx skills@latest add abgregs/skills@git-commit
```
