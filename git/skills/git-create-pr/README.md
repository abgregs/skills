# git-create-pr

Pushes the current branch and opens a pull request through `gh`, or rewrites the body of the PR already open for the branch. The body is written from the merge-base diff for a reviewer deciding whether to approve, and it is gated by a lint before anything ships.

## Invocation

```
/git-create-pr             # base branch resolved from the repo default
/git-create-pr develop     # override the base branch
```

Autonomous: it decides the title and body and runs the two mutating commands (`git push`, then `gh pr create` or `gh pr edit`). It stops only on a preflight abort or when push or `gh` fails.

## What it produces

- A body with `## Summary`, `## Changes`, `## Testing`, and `## Impact` only when there is a consequence to weigh; when the repo has a PR template, the body fills that template's shape instead
- A title under 70 characters that matches the repo's own style, read from its history
- The PR URL

The preflight reports only what git can prove: base branch, push state, divergence, an existing PR, the repo template, title style, merge risks, and generated files excluded from the diff the agent reads.

One stance to know before the first run: the body carries the change, never its provenance. No co-author line, tool or model name, session link, or robot emoji, even when the session's harness or instructions ask for one; the lint rejects them. If your team requires an attribution line in PR bodies, fork the skill and remove the provenance wall rather than arguing the agent past it.

## Files

- `SKILL.md` — the workflow the agent follows
- `scripts/pr-preflight.sh` — the detector; `--lint <body-file> "<title>"` checks sections, placeholders, provenance, and title style
- `examples/pr-body.md` — a filled body that lints clean, with notes on why

## Requirements

`git`, `bash`, and the GitHub CLI (`gh`) authenticated against the remote's host. Never force-pushes, bypasses hooks, merges, or marks a PR ready for review.

## Install

```bash
npx skills@latest add abgregs/skills@git-create-pr
```
