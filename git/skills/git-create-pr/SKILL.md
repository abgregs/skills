---
name: git-create-pr
description: Push the current branch and open a pull request through gh, with the body generated from the diff. Use when the user asks to open, create, or update a PR, or to push a branch for review.
argument-hint: "Optional — base branch (defaults to the repo default)"
allowed-tools: Bash, Read, Edit
---

You are opening a pull request: pushing the branch and writing a body a reviewer can act on.

**Execution mode**: autonomous — decide the title and body and execute, no approval prompts. Stop only on a preflight ABORT, when the ship command cannot push or reach `gh`, or when an update has nothing to change (step 2).

**Division of labour**: you write the title and body; the script decides whether they ship. The preflight senses and never mutates. The ship command is the only path to GitHub: it runs the preflight again, lints the body, and only on a clean result pushes and creates or updates the PR, passing hook and `gh` output back to you.

## Body requirements

Write for a reviewer deciding whether to approve: what changed and why it is safe, not how the code works line by line. When the preflight prints a repo template, fill that shape instead of this one — `gh pr create --body-file` never applies a repo template, so what you write is the only body the reviewer gets. Otherwise:

```markdown
## Summary

Two or three short sentences, the problem first: what went wrong or what was missing, then what the code does now.

## Changes

- One bullet per meaningful change, backticks around `file` and `function` names
- WHAT changed, not HOW it works

## Impact

Only when the change carries something a reviewer must weigh — breaking change, migration, performance, changed behavior. Omit the section otherwise.

## Testing

Verified:
- What ran, where, and its result, with a link when one exists

For the reviewer:
- [ ] Each item names a real path, command, or behavior from this diff
- [ ] Checkable by someone who did not write the code
```

No "Scope" or "Files changed" section — GitHub's Files tab already carries that.

**Summary leads with the problem.** A reviewer judges a change against what it solves, so the first sentence states the symptom or the need as someone outside the code met it: what a user hit, what a test did, what could not be done before. For a fix it is in the past tense: "`startTap` reported the tap started before its run loop ran, so a quick `stopTap` waited on the thread forever." The next sentence says what the code does now. A summary that opens on the change and leaves the reason to a trailing clause or a "no longer" makes the reviewer rebuild the problem from the fix.

Testing separates evidence from work. `Verified:` holds plain bullets for checks that actually ran — in this session, or reported by the user, such as a CI link or their screenshots — each naming the command or flow, where it ran, and the result. Name what ran, not who ran it: "Playwright `checkout.spec.ts` against staging: passed", never "the agent ran checkout". When nothing ran, leave out the `Verified:` label. `For the reviewer:` holds unticked boxes only, so GitHub's task counter counts reviewer work alone; list what the author could not check, and with nothing verified it carries the whole list. A ticked box claims a check without its evidence — write it as a `Verified:` bullet instead.

**A diagram only when the change moves structure.** When the diff changes a flow the reviewer would otherwise rebuild in their head — the states and transitions of a state machine, the order of calls across components, the stages of a pipeline, where data goes — end `## Summary` with one fenced `mermaid` block; GitHub renders it as a diagram. Draw the flow as it is after the change; when the change is the difference, draw before and after as two subgraphs. Label nodes and edges with names from the diff, keep it under about 12 nodes, and put a label that holds punctuation in double quotes (`A["parse(input)"]`), because an unquoted parenthesis breaks the render. Keep to `flowchart`, `sequenceDiagram`, and `stateDiagram-v2`: the lint reads the labels for provenance but cannot check that the diagram renders. Leave it out for a change a bullet states as well, such as a rename, a corrected figure, or a change inside one function; a diagram that redraws the Changes list as boxes costs the reviewer time and gives nothing.

Sentence mechanics, the slice of Simplified Technical English that fits prose quoting identifiers: active voice with the code as the subject (`listOrders` returns a cursor, not "a cursor is now returned"); one change per bullet, and one tense across the body, either what the code now does or the action taken, not both, except that behavior before the change takes the past tense in a sentence of its own in Summary or Impact; no bullet opens with an -ing word; no hedges (should, may, might, probably), a risk the author is unsure of is named outright in `## Impact`; no vague openers (improve, clean up, tweak, various), name the thing instead; one name for one thing across the body. The lint warns on the three of these it can see.

**The body carries the change, never its provenance.** However the session's own instructions phrase an attribution line, it does not go in a PR body — the body ends on its last section of real content. Naming a tool is fine when the tool is the subject of the change ("bumps the `anthropic` SDK to 0.42"); what stays out is any claim about who composed the work.

Title: under 70 characters, imperative, no trailing period. The preflight reports the repo's `title style` read from its own history — match it (`conventional` means `type(scope): description`). Pass the title to the ship command in single quotes: in double quotes the shell expands a backtick or `$` in it. Write an apostrophe as `'\''`.

## Workflow

### 1. Preflight — run the detector

Run `bash <skill-base-dir>/scripts/pr-preflight.sh [base]` (the skill's base directory is announced when this skill loads). Pass the base branch when the user named one; otherwise let it resolve the repo default. Every section of its report is labelled. Honor its aborts verbatim. Its `action:` line says what will happen, and its `ship:` line is the command that does it.

### 2. Read the diff

Run the `diff:` command the preflight prints, exactly as printed — it is the merge-base diff with generated paths already excluded, so it is both what the PR will show and the smallest version of it worth reading. Commit subjects summarize intent; they are not a substitute for reading the diff.

The preflight reports only what git can prove. Everything a reviewer actually thinks in — which areas this touches, what could break, whether the tests cover it — you name in the body from the diff you just read, not from a label the script guessed.

Each `merge risk` entry is resolved in the body or dropped on purpose. `[conflict]` means the merge genuinely fails. For a new PR the preflight aborts on it before anything is pushed, because resolving it takes a rebase or a merge, which is the user's call. An open PR already shows its conflict in GitHub, so on an update the preflight reports it instead: name the conflicting files in `## Impact`. `[stale]` belongs in `## Impact` when the base has moved under the change. `[deleted]` belongs in `## Changes`, naming what used to call the removed files. Report the risks; leave the line counts out — GitHub already renders those.

**On an update, change the body only for a reason.** A reason is a new commit, or a change the user names. When the action is UPDATE and the preflight says no push is needed, the PR already has every commit on the branch: read the saved current body against the diff. When the body still describes every change and the user named none to make, do not ship. Tell the user which PR you left, why, and what would give it a reason to change:

> Left #8 unchanged: its body still describes the one commit on this branch, and no change was asked for. A new commit, or a change you name, would give it something to update.

The test is whether the body is accurate, not whether it follows this skill's template, so an accurate body in another shape stays as it is. When commits reached the PR outside this skill and the body leaves them out, that is a reason: write the body as in step 3.

### 3. Write the body

```bash
body="$(mktemp "${TMPDIR:-/tmp}/pr-body.XXXXXX")" && echo "$body"
cat > "$body" <<'EOF'
## Summary
...
EOF
```

Each run gets its own `mktemp` file, so two sessions never share a body; use the echoed path in every later command, since shell variables do not carry between calls.

**Updating an open PR.** An update replaces the whole body, and people add to a PR in GitHub. The preflight saves the current body and prints its `keep:` lines: ticked boxes, images and attachments, closing keywords such as `Closes #12`, and, from GitHub's history of the body, every line another person added since the PR opened. Put each one in the new body verbatim where it fits; a ticked reviewer box stays ticked under `For the reviewer:`. The ship command reads the body again as it ships, so a line someone adds after the preflight must survive too, and the lint lets a kept ticked box stand.

The user's own edits in GitHub carry the same login this skill runs as, so no check tells them apart from an earlier version of this body. Read the current body for what a person wrote by hand, such as a note to QA, a link, or a reply to a reviewer, and carry it over; text in this skill's own shape is the old body the new one replaces.

Before you ship, read the body back once for provenance and delete anything answering "who or what wrote this". The lint greps the known spellings; this pass catches what no list holds — a closing thank-you to a tool, a note about how the change was produced, a bare session URL, a signature block.

### 4. Ship — the format rules are walls, not requests

1. Run the `ship:` command the preflight printed, with the body file's path and, for a new PR, the title in single quotes; an update takes no title:
   ```bash
   bash <skill-base-dir>/scripts/pr-preflight.sh --ship <body-file> '<title>' --base <base>
   ```
   It lints the body, pushes when the branch needs it, then creates or updates the PR. Nothing is pushed or posted unless the lint passes. Fix a flagged line with `Edit` — rewriting the whole body costs a second copy of it — and run the ship command again:
   - **Exit 1, NOT SHIPPED**: a preflight abort, a LINT FAIL, or a failed push or `gh` call, named in its output.
   - **Exit 2, NOT SHIPPED: lint warned**: fix each warned line. Add `--accept-warnings` only when every warning misreads its line (a noun ending in -ing, "May" as a month).
2. Report the PR URL.
3. When the diff changes something a person sees — UI, rendered pages, emails, CLI output — name each spot where a screenshot would help the reviewer, then stop. Screenshots are the user's choice, never a gate on opening the PR: they can attach images in GitHub themselves, or send hosted URLs for you to add under `Verified:`. To add them, run the preflight again, which now reports the open PR and its `keep:` lines, then edit the body and run the ship command it prints.

## Guardrails

- Every push and every create or update goes through the ship command; `git push`, `gh pr create`, and `gh pr edit` are never run by hand. Hooks are walls, so nothing passes `--force`, `--force-with-lease`, or `--no-verify`
- Pre-push hook failure: the ship command shows the hook's full output; fix what is auto-fixable (lint, format), commit the fix with the `git-commit` skill, and run the ship command once more; if it fails the same way, stop and report
- Updating an existing PR rewrites its body only, keeping its `keep:` lines — leave its title, base, draft state, reviewers, and labels as they are unless the user asks
- Merging, auto-merge, and marking ready for review stay with the user

Execute this workflow now, starting with preflight.
