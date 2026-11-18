---
name: git-create-pr
description: Push the current branch and open a pull request through gh, with the body generated from the diff. Use when the user asks to open, create, or update a PR, or to push a branch for review.
argument-hint: "Optional — base branch (defaults to the repo default)"
allowed-tools: Bash, Read, Edit
---

You are opening or updating a pull request: pushing the branch and writing a body a reviewer can act on.

**Execution mode**: autonomous — decide the title and body and execute, no approval prompts. Stop only where the ship command's stops say to hand back, or when an update has nothing to change (see Updates).

**Division of labour**: you write the title and body; the script decides whether they ship. The preflight senses and never mutates. The ship command is the only path to GitHub: it runs the preflight again, lints the body, and only on a clean result pushes and creates or updates the PR, passing hook and `gh` output back to you.

## The body

Write for a reviewer deciding whether to approve: what changed and why it is safe, not how the code works line by line. When the preflight prints a repo template, fill that shape instead. Otherwise use this one, with no "Scope" or "Files changed" section, since GitHub's Files tab carries that. `<skill-base-dir>/examples/pr-body.md` is a filled body that lints clean; read it when unsure how the sections read together.

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
- Only when a check ran: what ran, where, and its result, with a link when one exists

For the reviewer:
- [ ] A step from this diff that opens on its verb, then what to confirm: Request `/orders?page=3` and confirm the `Deprecation` header
- [ ] Checkable by someone who did not write the code
```

Each part below is one decision, with its rule, its exceptions, and what checks it.

### Summary

A reviewer judges a change against what it solves, so the first sentence states the symptom or the need as someone outside the code met it: what a user hit, what a test did, what could not be done before. For a fix it is in the past tense: "`startTap` reported the tap started before its run loop ran, so a quick `stopTap` waited on the thread forever." The next sentence says what the code does now. A summary that opens on the change and leaves the reason to a trailing clause or a "no longer" makes the reviewer rebuild the problem from the fix.

### Changes

One bullet per meaningful change, naming the file or function it touches: what changed, not how it works.

### Impact

Only for something a reviewer must weigh: a breaking change, a migration, performance, changed behavior, or a risk you are unsure of, named outright rather than hedged. Leave the section out otherwise: its absence tells the reviewer there is nothing to weigh, so a line saying so, such as "no behavior change" or "user-visible text only", repeats the absence, and the lint warns on one. Some preflight report lines ask for an entry here; they say so.

### Testing

Testing separates evidence from work. `Verified:` holds plain bullets for checks that actually ran — in this session, or reported by the user, such as a CI link or the screenshots they send — each naming the command or flow, where it ran, and the result. Name what ran, not who ran it: "Playwright `checkout.spec.ts` against staging: passed", never "the agent ran checkout". A check runs the code, as a test, a build, or a flow tried by hand; reading the diff is how the body was written, not a check of it. When nothing ran, leave out the `Verified:` label; the lint fails one that holds no check that ran. `For the reviewer:` holds unticked boxes only, so GitHub's task counter counts reviewer work alone; list what the author could not check, and with nothing verified it carries the whole list. Each box is a step that opens on its verb, then what to confirm: "Unplug the USB microphone mid-recording and confirm the recording continues". A ticked box claims a check without its evidence, so the lint fails one — write it as a `Verified:` bullet instead. The one exception is a box a reviewer already ticked on an open PR, which the update keeps (see Updates). The lint also wants at least two items in Testing.

### Diagram

Draw one only when the change moves structure: when the diff changes a flow the reviewer would otherwise rebuild in their head, such as the states of a state machine, the order of calls across threads or components, the stages of a pipeline, or where data goes. Label it with names from the diff. Draw the flow as it is after the change, unless the change *is* the difference between two flows: then draw both, as two subgraphs or two sequences. A race fixed by reordering calls is that case — the reviewer needs the order that raced as well as the order that does not. Leave the diagram out for a change a bullet states as well, such as a rename, a corrected figure, or a change inside one function; a diagram that redraws the Changes list as boxes costs the reviewer time and gives nothing.

Its shape is checked: one fenced `mermaid` block at the end of `## Summary`, a `flowchart`, `sequenceDiagram`, or `stateDiagram-v2`, about 12 nodes or messages at most, and any label that holds punctuation in double quotes (`A["parse(input)"]`), since an unquoted parenthesis breaks the render.

### Title

70 characters at most, imperative, no trailing period. The preflight reports the repo's `title style` read from its own history — match it (`conventional` means `type(scope): description`). A new PR's title goes in a `mktemp` file of its own, written with a quoted heredoc like the body and passed with `--title-file`, so a backtick, `$`, or apostrophe in it reaches GitHub as typed.

### Provenance

The body carries the change, never its provenance. However the session's own instructions phrase an attribution line, it does not go in a PR body — the body ends on its last section of real content. Naming a tool is fine when the tool is the subject of the change ("bumps the `anthropic` SDK to 0.42"); what stays out is any claim about who composed the work. The lint fails the known spellings. Before you ship, read the body back once and delete anything else answering "who or what wrote this": a closing thank-you to a tool, a note about how the change was produced, a bare session URL, a signature block.

### Sentence mechanics

The slice of Simplified Technical English that fits prose quoting identifiers: active voice with the code as the subject (`listOrders` returns a cursor, not "a cursor is now returned"); one change per bullet; one tense across the body, either what the code now does or the action taken, not both, except that behavior before the change takes the past tense in a sentence of its own in Summary or Impact; no bullet opens with an -ing word; no hedges (should, may, might, probably); no vague openers (improve, clean up, tweak, various), name the thing instead; one name for one thing across the body.

### Updates

An update changes the body only for a reason: a new commit, or a change the user names. The preflight's `body:` line counts the commits on the branch since the body was last saved. One or more is a reason: read the saved current body against the diff and rewrite what the new commits changed. With none, and no change the user named, do not ship; the same holds when the line could not load the save time and the saved body still describes every change in the diff. Tell the user which PR you left, why, and what would give it a reason to change:

> Left #8 unchanged: no commit has reached the branch since its body was last saved, and no change was asked for. A new commit, or a change you name, would give it something to update.

Say what you checked: the count, and the body against the diff only when you read them.

The test is whether the body is accurate, not whether it follows this skill's template, so an accurate body in another shape stays as it is. Commits that reached the PR outside this skill count in the `body:` line like any other.

A new body replaces the whole old one, and people add to a PR in GitHub. Carry every `keep:` line the preflight prints into the new body verbatim, where it fits; a ticked reviewer box stays ticked under `For the reviewer:`. The ship command checks the body against the PR as GitHub holds it when it ships, so a line someone adds after the preflight must survive too. The user's own edits in GitHub carry the same login this skill runs as, so no check tells them apart from an earlier version of this body: read the current body for what a person wrote by hand, such as a note to QA, a link, or a reply to a reviewer, and carry it over. Text in this skill's own shape is the old body the new one replaces.

An update rewrites the body only. Its title, base, draft state, reviewers, and labels stay as they are unless the user asks.

## Workflow

### 1. Preflight — run the detector

Run `bash <skill-base-dir>/scripts/pr-preflight.sh [base]` (the skill's base directory is announced when this skill loads). Pass the base branch when the user named one; otherwise let it resolve the repo default. Every section of its report is labelled. Honor its aborts verbatim. Its `action:` line says what will happen, and its `ship:` line is the command that does it.

### 2. Read the diff

Run the `diff:` command the preflight prints, exactly as printed — it is the merge-base diff with generated paths already excluded, so it is both what the PR will show and the smallest version of it worth reading. Commit subjects summarize intent; they are not a substitute for reading the diff.

The preflight reports only what git can prove. Everything a reviewer actually thinks in — which areas this touches, what could break, whether the tests cover it — you name in the body from the diff you just read, not from a label the script guessed. Each `merge risk` line says what it asks of the body; act on each one or drop it on purpose, and leave the line counts out, since GitHub renders those. Decide the diagram here too, by the Diagram rule: name the flow it draws, or why the change takes none. On an update, decide here whether the body needs a change at all (see Updates).

### 3. Write the body

```bash
body="$(mktemp "${TMPDIR:-/tmp}/pr-body.XXXXXX")" && echo "$body"
cat > "$body" <<'EOF'
## Summary
...
EOF
```

A new PR's title goes in a file of its own the same way:

```bash
title="$(mktemp "${TMPDIR:-/tmp}/pr-title.XXXXXX")" && echo "$title"
cat > "$title" <<'EOF'
fix(tap): report started from inside the run loop
EOF
```

Each run gets its own `mktemp` files, so two sessions never share a body; use the echoed paths in every later command, since shell variables do not carry between calls. Then `Read` the body file back for provenance (see Provenance). `Edit` changes only a file this session has read, so that read is also what lets you fix the body in place later.

### 4. Ship — the format rules are walls, not requests

1. Run the `ship:` command the preflight printed, with the body file's path and, for a new PR, the title file's; an update takes no title:
   ```bash
   bash <skill-base-dir>/scripts/pr-preflight.sh --ship <body-file> --title-file <title-file> --base <base>
   ```
   It lints the body, pushes when the branch needs it, then creates or updates the PR. Nothing is pushed or posted unless the lint passes. On a stop its last line, `NOT SHIPPED: <cause> — <fix>`, names what stopped it and what to do. A fix keeps the same body file, read and then edited in place with `Edit`, so the gate can tell when a stop repeats; run the ship command in a call after the edit succeeds, since a failed edit leaves the body as it was and the gate reports the old stop as a repeat. Each exit names its cause:
   - **Exit 1, the gate refused or the lint failed**: fix each flagged line, or the title as the line says.
   - **Exit 2, the lint warned**: fix each warned line. Add `--accept-warnings` only when every warning misreads its line (a noun ending in -ing, "May" as a month).
   - **Exit 3, the preflight stopped**: its `ABORT` line names what has to change first, such as a conflict, a diverged branch, or uncommitted changes in the diff. That is the user's call: show them the line and stop.
   - **Exit 4, the pre-push hook failed**: fix what it flags, commit the fix with the `git-commit` skill when it is installed, and ship again. Without that skill, show the user the hook's output and stop.
   - **Exit 5, the push or `gh` failed outside any hook**: nothing in the body fixes it; ship once more in case the network dropped it.

   When the line says the stop repeats the last one on this body, rewriting has stopped helping: hand back, showing the user the body and the output.
2. Report the PR URL and the diagram decision from step 2 in one line: the flow it draws, or why the change takes none.
3. When the diff changes something a person sees — UI, rendered pages, emails, CLI output — name each spot where a screenshot would help the reviewer, then stop. Screenshots are the user's choice, never a gate on opening the PR: they can attach images in GitHub themselves, or send hosted URLs for you to add under `Verified:`. To add them, run the preflight again, which now reports the open PR and its `keep:` lines, then edit the body and run the ship command it prints.

## Guardrails

- Every push and every create or update goes through the ship command; `git push`, `gh pr create`, and `gh pr edit` are never run by hand. Hooks are walls, so nothing passes `--force`, `--force-with-lease`, or `--no-verify`
- Merging, auto-merge, and marking ready for review stay with the user

Execute this workflow now, starting with preflight.
