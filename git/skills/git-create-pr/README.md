# git-create-pr

Pushes the current branch and opens a pull request through `gh`, or rewrites the body of the PR already open for the branch. The body is written from the merge-base diff for a reviewer deciding whether to approve, and it is gated by a lint before anything ships.

## Invocation

```
/git-create-pr             # base branch resolved from the repo default
/git-create-pr develop     # override the base branch
```

Autonomous: it decides the title and body, then ships them through one gate that runs the preflight again, lints the body, and only on a clean result pushes and runs `gh pr create` or `gh pr edit`. Each stop names its cause and what to do; a preflight abort, a stop that repeats, and a failure no rewrite fixes come back to you.

## What it produces

- A body with `## Summary`, `## Changes`, `## Testing`, and `## Impact` only when there is a consequence to weigh; when the repo has a PR template, the body fills that template's shape instead
- A title of 70 characters at most that matches the repo's own style, read from its history
- A `## Testing` section that separates checks already run, cited with their results under `Verified:`, from unticked boxes left for the reviewer
- One Mermaid diagram at the end of `## Summary`, only when the change moves a flow, a state machine, or a call order; GitHub renders it, so nothing extra is installed. The lint checks its shape: one block, inside Summary, a flowchart, sequence, or state diagram, about 12 nodes, quoted labels
- On an update, a new body that keeps what people added in GitHub: ticked boxes, images and attachments, closing keywords such as `Closes #12`, and any line another person added since the PR opened, read from GitHub's history of the body. Your own edits share the login the skill runs as, so it finds those by reading the body, not by a check. The preflight counts the commits since the body was last saved; with none and no change asked for, it leaves the body as it is and says so, rather than rewording it
- The PR URL, plus, when the diff changes something a person sees, the spots where a screenshot would help; adding them is optional, and hosted URLs sent back are written into the body and shipped through the same gate

The preflight reports only what git can prove: base branch, push state, divergence, an existing PR, the repo template, title style, merge risks, and generated files excluded from the diff the agent reads. It stops a new PR whose branch conflicts with the base, because resolving that takes a rebase or merge, which is yours to decide.

## Stances

Installing the skill opts into two opinions. Both are enforced by the lint, so they are worth knowing before the first run.

- **A template file wins; prose conventions do not.** When the repo has a pull request template file (`.github/pull_request_template.md` or a `PULL_REQUEST_TEMPLATE` folder), the body fills that template's shape, and the lint checks its headings, labels, and checklist items. A PR skeleton described in the repo's prose docs, such as a contributing guide, is advice no tool enforces, so the skill writes its own shape instead; in every evidence case a bare agent followed one such skeleton and the skill did not. To make the skill follow yours, put it in a template file. This is the same stance `git-commit` takes on subject formats.
- **The body carries the change, never its provenance.** No co-author line, tool or model name, session link, or robot emoji, even when the session's harness or instructions ask for one; the lint rejects them. If your team requires an attribution line in PR bodies, fork the skill and remove the provenance wall rather than arguing the agent past it.

## Files

- `SKILL.md` — the workflow the agent follows
- `scripts/pr-preflight.sh` — the detector and the gate. `--ship <body-file> --title-file <title-file>` is the only path to GitHub: it reruns the preflight, lints, then pushes and creates or updates the PR, so a body that fails the lint never ships. The title travels in a file like the body, so no shell quoting touches it. Each stop prints a `NOT SHIPPED` line with its cause and exits 1 when the gate refused or the lint failed, 2 when the lint warned, 3 when the preflight stopped, 4 when the pre-push hook failed, and 5 when the push or `gh` failed outside any hook; a stop that repeats the last one on the same body says to hand back to you. `--lint <body-file> --title-file <title-file>` is the check it runs: sections, placeholders, provenance, and title style, every hit of each in one pass; exit 2 on a warning until it is fixed or passed with `--accept-warnings`; with `--existing <file>` and `--keep <file>`, a failure for a body that drops a line people added to the open PR
- `examples/pr-body.md` — a filled body that lints clean, with notes on why; `SKILL.md` points the agent to it when it is unsure how the sections read together
- `evidence/` — recorded runs, most against a bare agent on the same branch, one case per file, with the method to rerun them and the skill hash each batch ran on

## Requirements

`git`, `bash`, and the GitHub CLI (`gh`) authenticated against the remote's host. Optional: the [`git-commit`](../git-commit) skill. When a pre-push hook fails on something auto-fixable, the skill commits the fix through `git-commit` and ships again; without it, the skill stops and reports the hook's output. Never force-pushes, bypasses hooks, merges, or marks a PR ready for review.

## Install

```bash
npx skills@latest add abgregs/skills@git-create-pr
```
