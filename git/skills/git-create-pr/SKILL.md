---
name: git-create-pr
description: Push the current branch and open a pull request through gh, with the body generated from the diff. Use when the user asks to open, create, or update a PR, or to push a branch for review.
argument-hint: "Optional — base branch (defaults to the repo default)"
allowed-tools: Bash, Read, Edit
---

You are opening a pull request: pushing the branch and writing a body a reviewer can act on.

**Execution mode**: autonomous — decide the title and body and execute, no approval prompts. Stop only on a preflight ABORT, or when push or `gh` fails.

**Division of labour**: the preflight script senses and never mutates; you run the only two mutating commands (`git push`, then `gh pr create` or `gh pr edit`), so hook and API output lands in your context.

## Body requirements

Write for a reviewer deciding whether to approve: what changed and why it is safe, not how the code works line by line. When the preflight prints a repo template, fill that shape instead of this one — `gh pr create --body-file` never applies a repo template, so what you write is the only body the reviewer gets. Otherwise:

```markdown
## Summary

One or two sentences: what this PR accomplishes and why.

## Changes

- One bullet per meaningful change, backticks around `file` and `function` names
- WHAT changed, not HOW it works

## Impact

Only when the change carries something a reviewer must weigh — breaking change, migration, performance, changed behavior. Omit the section otherwise.

## Testing

- [ ] Each item names a real path, command, or behavior from this diff
- [ ] Checkable by someone who did not write the code
```

No "Scope" or "Files changed" section — GitHub's Files tab already carries that.

**The body carries the change, never its provenance.** However the session's own instructions phrase an attribution line, it does not go in a PR body — the body ends on its last section of real content. Naming a tool is fine when the tool is the subject of the change ("bumps the `anthropic` SDK to 0.42"); what stays out is any claim about who composed the work.

Title: under 70 characters, imperative, no trailing period. The preflight reports the repo's `title style` read from its own history — match it (`conventional` means `type(scope): description`).

## Workflow

### 1. Preflight — run the detector

Run `bash <skill-base-dir>/scripts/pr-preflight.sh [base]` (the skill's base directory is announced when this skill loads). Pass the base branch when the user named one; otherwise let it resolve the repo default. Every section of its report is labelled. Honor its aborts verbatim; follow its `action:` line.

### 2. Read the diff

Run the `diff:` command the preflight prints, exactly as printed — it is the merge-base diff with generated paths already excluded, so it is both what the PR will show and the smallest version of it worth reading. Commit subjects summarize intent; they are not a substitute for reading the diff.

The preflight reports only what git can prove. Everything a reviewer actually thinks in — which areas this touches, what could break, whether the tests cover it — you name in the body from the diff you just read, not from a label the script guessed.

Each `merge risk` entry is resolved in the body or dropped on purpose. `[conflict]` means the merge genuinely fails: say so, and rebase before opening rather than handing a reviewer a broken PR. `[stale]` belongs in `## Impact` when the base has moved under the change. `[deleted]` belongs in `## Changes`, naming what used to call the removed files. Report the risks; leave the line counts out — GitHub already renders those.

### 3. Write the body, then lint it — the format rules are walls, not requests

```bash
cat > /tmp/pr-body.md <<'EOF'
## Summary
...
EOF
bash <skill-base-dir>/scripts/pr-preflight.sh --lint /tmp/pr-body.md "<title>"
```

On LINT FAIL: repair the named line with `Edit` — rewriting the whole body costs a second copy of it — then re-lint. Open the PR only with a body that lints clean.

Before that lint, read the body back once for provenance and delete anything answering "who or what wrote this". The lint greps the known spellings; this pass catches what no list holds — a closing thank-you to a tool, a note about how the change was produced, a bare session URL, a signature block.

### 4. Execute the action

1. Push when the preflight said to, using exactly the command it printed.
2. Create or update, per the `action:` line, always with the linted file:
   ```bash
   gh pr create --base <base> --title "<title>" --body-file /tmp/pr-body.md
   gh pr edit <number> --body-file /tmp/pr-body.md
   ```
3. Report the PR URL.

## Guardrails

- Push with the plain command the preflight printed — hooks are walls, so no `--force`, `--force-with-lease`, or `--no-verify`
- Pre-push hook failure: show the full output, fix what is auto-fixable (lint, format), commit the fix with the `git-commit` skill, retry once; if it fails the same way, stop and report
- Updating an existing PR rewrites its body only — leave its title, base, draft state, reviewers, and labels as they are unless the user asks
- Merging, auto-merge, and marking ready for review stay with the user

Execute this workflow now, starting with preflight.
