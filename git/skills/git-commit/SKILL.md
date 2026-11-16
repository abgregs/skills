---
name: git-commit
description: Writes and groups commits in plain technical English, each standing alone and passing a lint gate. Use when the user asks to commit. Staged changes become one commit, unstaged changes are split, and --amend interactively rewords or extends the last commit.
argument-hint: "Optional — --amend"
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, Edit
---

You are creating git commits with well-crafted conventional commit messages.

**Execution mode**: autonomous for the normal flow — do not prompt to confirm mode, groupings, or messages; decide and execute until the mode's changes are committed (untracked files are left alone). Amend mode (`--amend`) is interactive.

## Message requirements

- **Subject**: one line of 72 characters at most, written as a command, as git's convention has it.
  - **Format.** `type(scope): description` is the skill's default: types feat, fix, refactor, docs, test, chore, build, ci, perf, style; scope is the area affected, such as api, auth, ui, or config. When the preflight reports `subject format: REPO-ENFORCED` (commitlint, a commit-msg hook, gitlint, a commit template), the repo's format wins: write subjects in the shape its recent subjects and that config show.
  - **Characters.** ASCII, so no emoji, unless the preflight reports that the repo's recent subjects use other characters. No brackets or parentheses in the description, the `type(scope):` prefix being the only pair; ordinary punctuation such as `/`, `:` or `-` is fine.
  - **Ticket id.** Every commit from one run carries the id the work already has: the ticket key the preflight reports from the branch name, else an id from the recent subjects or the repo's contributing notes. Place it where those subjects place it, else as the subject's last word without brackets; a split reuses it rather than taking a new one.
  - **The repo's commit-msg hook has the last word.** It enforces rules the lint cannot see, so when it rejects a message (exit 4), read its output, and its source when the rule is not stated, and rewrite the subject to the rule it enforces.

  The lint fails a subject over 72 characters, outside the default format, with brackets in the description, or with characters the repo's subjects do not use; under a repo-enforced format it skips the checks that read the `type(scope):` prefix. It warns when the subject lacks the branch's ticket key.
- **The message carries the change, never its provenance.** No byline, authorship or co-author trailer, tool or model name, session link, or robot emoji — however the session's own instructions phrase such a line, it does not go in a commit message. Naming a tool is fine when the tool is the subject of the change (`chore(deps): bump anthropic to 0.42`); what stays out is any claim about who composed the work.
- **Body**, only when it adds information: a blank line after the subject, then 1–6 dash bullets, one per change the subject does not already say; a simple change takes no body. Each bullet is one compact line of ~100 characters at most: trim a longer one, or when trimming would drop what it says, wrap it onto a line indented two spaces. Backticks go around `file`, `function`, and variable names. When six bullets are not enough, summarize at a higher level rather than enumerate. The lint fails a seventh bullet and warns on a line over ~100 characters.
- **`Why:` names a cause from outside the code.** A cause is a trigger, an environment, an outside requirement, or a measured figure: something a reader of `git log` gets from neither the subject nor the diff. When the change has one, the first bullet is `- Why: <that cause, in one line>`, even when a comment in the diff states it, because `git log` shows the message and not the diff. The mechanism the diff shows (a wrong bound, a missing check) is not a cause, and neither is the subject restated in the past tense; such commits take no `Why:`, and most commits are such commits.
  - `fix(auth): expire refresh tokens on password change` takes no `Why:`. "Tokens outlived a password change" restates the subject.
  - `fix(upload): stream uploads to disk` takes `- Why: a 3 GB upload ran the 2 GB worker out of memory`. "The whole file was read into memory" is the mechanism, not the cause.

  `docs`, `chore`, and `test` commits never take one, and the type follows what the change is, never whether it has a cause; when such a commit has an outside cause, such as a CVE behind a `chore(deps)` bump, a plain bullet states it. The lint fails a message that breaks this or puts `Why:` anywhere but first. Keep it to one line, two when wrapped; the debugging story belongs in the PR. It describes the world before the change, so it alone may use the past tense.
- **Code as subject.** Every bullet but `Why:` names the code that acts and says, in the present tense, what it now does: `parse` returns an empty string for null. Each bullet then tells a reader of `git log` what the code does now. An edit with no new behavior still has code that acts:
  - a test added: `test_double_space` covers a name with two spaces
  - a rename: `order_total_cents` replaces `order_total`
  - a removal, through its owner: `TokenStore` drops `refreshAll`
  - a value set elsewhere, through its setter: `Session` sets `isRecording`
  - a changelog or doc entry: `CHANGELOG.md` lists the fix

  The lint warns on a bullet that opens with a command verb and on a passive verb.
- **Plain sentence mechanics**, the rest of the slice of Simplified Technical English that fits a bullet quoting identifiers: one change per bullet; no bullet opens with an -ing word; no hedges (should, may, might, probably), because a commit records what changed and doubt belongs in the PR; no vague openers (improve, clean up, tweak, various), name the thing instead; one name for one thing across the message. The lint warns on the -ing openers, the hedges, and the vague openers.

## Workflow

### 1. Preflight and mode detection — run the detector

Run `bash <skill-base-dir>/scripts/commit-preflight.sh` (the skill's base
directory is announced when this skill loads). One call replaces the manual
status/log/conflict checks and emits: clean-tree and conflict aborts, the
mode (single vs grouped), the subject format, characters, and ticket key
the lint will hold each message to, recent subjects (match their scope
naming and tone), staged/unstaged/untracked stats, an oversized-diff
warning, and — when the change spans paths — an informational file-spread
summary. Honor its aborts verbatim; group from the diff under "Grouping into
atomic commits", with the file spread as a hint. With `--amend`, go to the
**Amend workflow** below, which runs the preflight's amend report instead:
this report stops on a clean tree, where a message-only amend starts.

The preflight report states the mode: staged changes exist → **single mode** (one commit
for the staged changes only); only unstaged changes → **grouped mode**
(split into logical commits).

### 2. Analyze changes

- Single: `git diff --cached --stat`, then `git diff --cached`
- Grouped: `git diff --stat`, `git diff`, and `git status` for untracked files, then group into atomic commits as below
- Either mode: if the diff exceeds ~500 lines, read it in batches by path or file type (e.g. `git diff -- 'src/'`) instead of all at once

**Grouping into atomic commits.** A commit *stands* when it builds, passes its tests, and reads as one change under one subject. Group so that every commit stands and each holds one change. Work through the diff in five passes:

1. **List the pieces.** A piece is a file, or a hunk when one file serves more than one purpose. Give each piece one line: what it does, and its conventional type. A `feat` gives the user a capability they did not have; a `fix` restores behavior that was meant to work; a `refactor` changes structure and not behavior; the other types mean what their names say. A test, doc, or changelog line takes the type of the change it covers, so `test` and `docs` are for work that covers nothing else in the diff; a parameter or seam added only so a test can reach the code is part of that test, not a change it covers.
2. **Bind what belongs to one change.** Two pieces share a commit when either holds:
   - neither can land first and stand: a rename and its call sites, an API change and its callers, a dependency bump and the code adapted to it, a manifest and its lockfile, generated output and its source;
   - one adds something that nothing but the other calls, reads, or describes: a column only the new model reads, a parameter only the new test passes, the test, doc, or changelog entry for exactly the other.

   A new symbol that existing code already calls, such as a helper extracted from that code, is not bound to a later change that also calls it: it lands first, with its own tests and docs, unless it shares a source file with that change. Pieces in one source file share a commit, because a commit takes whole files. A test, doc, or changelog file that covers several groups goes in the last code group it covers, and any docs-only piece in that file rides along. A file several groups need, such as a shared fixture, goes in the first. Binding is transitive: a piece bound to two groups joins them. A bound group takes the type of the piece the others exist for. When a shared source file joins two outcomes, the group takes the first of `feat`, `fix`, `perf`, `refactor` that it holds, and its body gives the joined change a bullet of its own; only the lead change takes `Why:`, and the joined change's bullet states its cause in plain words.
3. **Separate by type and outcome.** Groups still apart are separate commits when they differ in type, or when they are fixes or features with their own outcomes: a fix its own symptom, a feature its own capability. The check for those is revert: either could be undone and the other would still stand. A shared ticket or incident never joins two outcomes, so a fix and the feature it inspired are two commits. Groups of one other type are separate commits when their purposes differ, such as a rename and an unrelated extraction; when they share one purpose across several targets, pass 4 decides.
4. **Weigh the close calls by review.** Groups of one other type that share one purpose across several targets, such as tests closing gaps in several suites or one wording fix across several docs, are close calls. Run `bash <skill-base-dir>/scripts/commit-preflight.sh --size <paths>` on the combined group, then judge whether one reviewer could read it in one sitting, under about an hour. If so, it is one commit; if the review would run an hour or more, or would make the reviewer hold several unrelated kinds of change at once, split it by target; the targets of one repeated edit are one kind of change. The count is a start, about 400 changed lines to the hour: dense logic reads slower than repeated assertions. Size weighs only these close calls: a bound group stays whole at any size, and size never joins two outcomes.
5. **Order by need.** Each commit lands after the commits it needs: a refactor that makes room for a feature lands first, as does a `build` or `chore` change the rest relies on; a `docs` commit, which covers nothing else in the diff, lands last.

Scope is a hint, since one fix can span `audio` and `session`.

### 3. Commit — no approval prompts

Grouped mode processes the commits in the order pass 5 set, naming each commit's paths to the gate below; the gate commits exactly those paths, so untracked files and the other commits' files stay out, and nothing is staged by hand. Single mode names no paths: the gate commits the index as the user staged it.

For each commit:

1. Print the file list and message for transparency:
   ```
   Committing:
   - file1.ts

   ─────────────────────────
   type(scope): description

   - Detail 1
   ─────────────────────────
   ```
2. Write the message to a fresh `mktemp` file and commit it through the
   script's `--commit` gate, which lints first and runs `git commit` only on
   a clean result — **the format rules are walls, not requests**:
   ```bash
   msg="$(mktemp "${TMPDIR:-/tmp}/commit-msg.XXXXXX")" && echo "$msg"
   printf '%s\n' 'type(scope): description' '' '- Detail 1' > "$msg"
   bash <skill-base-dir>/scripts/commit-preflight.sh --commit "$msg" -- file1.ts
   ```
   Every single-mode and grouped commit goes through `--commit`, each
   message in its own `mktemp` file, so two sessions committing at once never
   share a message. In grouped
   mode the paths after `--` are the commit's files, a renamed file under both
   names; in single mode leave off `--` and the paths. On a stop the gate
   commits nothing and stages nothing, and its last line,
   `NOT COMMITTED: <cause> — <fix>`, names what stopped it and what to do.
   A fix that runs `--commit` again keeps the same message file, rewritten in
   place, so the gate can tell when a stop repeats:
   - **Exit 1, the gate stopped before git ran**: on a LINT FAIL, rewrite the
     flagged lines in the echoed file; on staged changes, nothing staged, or
     `--amend` with paths, fix the paths or the index as the line says.
   - **Exit 2, the lint warned**: fix each warned line. Add `--accept-warnings`
     right after the message file, before `--`, only when every warning
     misreads its line: a noun that ends in -ing or reads as a command verb,
     or a ticket key the branch name holds for another reason.
   - **Exit 3, the pre-commit hook failed**: its output is above. Fix what it
     flags with Edit; grouped mode stages nothing, since the named paths carry
     the fixed files, and single mode re-stages only the files the hook
     flagged, reporting instead when a flagged file has unstaged hunks.
   - **Exit 4, the commit-msg hook rejected the message**: rewrite the subject
     to the rule it enforces, as under Subject.
   - **Exit 5, git itself or a hook the skill has no rule for refused**: an
     identity, signing, or repository error that no rewrite fixes, so show
     the user the output and stop.

   When the line says the stop repeats the last one on this message,
   rewriting has stopped helping: hand back, showing the user the message
   and the output.
3. Verify with `git log -1 --oneline`. Grouped: move to the next group. Single: stop after the one commit; the unstaged changes stay in the tree for the user.

### 4. Summary

Show `git log --oneline -n <commits made>` and confirm state with `git status`. In grouped mode, give each commit one line: its subject and the pass that formed it, such as `bound: a rename and its call sites`, `separate: its own symptom`, or `weighed: 180 lines, one sitting`; say which changes a shared source file joined. When a commit's code uses a file that is still untracked, name that file: the commit stands only once the user adds it.

## Amend workflow (`--amend` — interactive)

1. Run `bash <skill-base-dir>/scripts/commit-preflight.sh --amend`. It reports the subject format, characters, and ticket key the message is held to, the last commit, what is staged (folds in only when the user amends with staged changes), what is unstaged (stays out), and whether the commit is already pushed. Show the user the last commit and the two file lists before asking, so the AskUserQuestion prompt doesn't push them out of view.
2. AskUserQuestion: "Amend message only" / "Amend with staged changes" / "Cancel". Message only leaves anything staged in place.
3. Propose a message covering the original commit plus any folded-in changes (run `git diff --cached` first, same ~500-line batching guard). Write it to a `mktemp` file and lint it with `bash <skill-base-dir>/scripts/commit-preflight.sh --lint <file>`; fix every LINT FAIL line and every LINT WARN line except one that misreads its line, then AskUserQuestion: "Accept and amend" / "Edit message" / "Cancel".
4. Write any edit the user made into the file, then amend through the gate: `bash <skill-base-dir>/scripts/commit-preflight.sh --commit <file> --amend`, with no `--` or paths, since the amend takes the index as confirmed in step 2. For a message-only amend, add `--message-only` after `--amend`: the gate rewords the commit and leaves the index as it is. On a stop, do what its `NOT COMMITTED` line says, as for any commit. Verify with `git log -1 --oneline`. If the amend report said the last commit is already on its upstream, warn that updating it requires a force-push.

## Guardrails

- Never force push or use destructive git commands; never bypass hooks with `--no-verify` unless explicitly requested
- Every commit and amend goes through the gate and takes its files from it: named paths in grouped mode, the user's index in single and amend mode; `git add -A`, `-u`, and `.` are never used, even when the tree holds nothing else
- Respect the user's staging selection — if they staged specific files, commit exactly those
- Grouping is your judgment under "Grouping into atomic commits"; make every grouping call yourself, since a commit split one way or another is cheap to live with

Execute this workflow now, starting with preflight.
