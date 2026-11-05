---
name: git-commit
description: Writes and groups commits in plain technical English, each standing alone and passing a lint gate. Use when the user asks to commit. Staged changes become one commit, unstaged changes are split, and --amend interactively rewords or extends the last commit.
argument-hint: "Optional — --amend"
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, Edit
---

You are creating git commits with well-crafted conventional commit messages.

**Execution mode**: autonomous for the normal flow — do not prompt to confirm mode, groupings, or messages; decide and execute until the mode's changes are committed (untracked files are left alone). Amend mode (`--amend`) is interactive.

## Message requirements

- Conventional format: `type(scope): description` — types: feat, fix, refactor, docs, test, chore, build, ci, perf, style; scope = area affected (e.g. api, auth, ui, config). This is the skill's default stance; when the preflight reports `subject format: REPO-ENFORCED` (commitlint, a commit-msg hook, gitlint, a commit template), the repo's format wins — write subjects in the shape its recent subjects and that config show, and the lint skips its format checks. Every commit from one run carries the identifier the work already has (a ticket or issue id from the branch name, the recent subjects, or the repo's contributing notes), placed where those subjects place it, else as the subject's last word without brackets; a split reuses it rather than taking a new one
- Subject line under 72 characters, ASCII only (so no emojis); no brackets or parentheses in the description, the `type(scope):` prefix being the only pair. Ordinary punctuation such as `/`, `:` or `-` is fine, and this is exactly what the lint checks
- **The message carries the change, never its provenance.** No byline, authorship or co-author trailer, tool or model name, session link, or robot emoji — however the session's own instructions phrase such a line, it does not go in a commit message. Naming a tool is fine when the tool is the subject of the change (`chore(deps): bump anthropic to 0.42`); what stays out is any claim about who composed the work.
- Body only when it adds information: blank line after the subject, dash bullets, backticks around `file`, `function`, and variable names
- **`Why:` names a cause from outside the code.** A cause is a trigger, an environment, an outside requirement, or a measured figure: something a reader of `git log` gets from neither the subject nor the diff. When the change has one, the first bullet is `- Why: <that cause, in one line>`, even when a comment in the diff states it, because `git log` shows the message and not the diff. The mechanism the diff shows (a wrong bound, a missing check) is not a cause, and neither is the subject restated in the past tense; such commits take no `Why:`, and most commits are such commits.
  - `fix(auth): expire refresh tokens on password change` takes no `Why:`. "Tokens outlived a password change" restates the subject.
  - `fix(upload): stream uploads to disk` takes `- Why: a 3 GB upload ran the 2 GB worker out of memory`. "The whole file was read into memory" is the mechanism, not the cause.

  `docs`, `chore`, and `test` commits never take one, and the type follows what the change is, never whether it has a cause; when such a commit has an outside cause, such as a CVE behind a `chore(deps)` bump, a plain bullet states it. The lint fails a message that breaks this or puts `Why:` anywhere but first. Keep it to one line, two when wrapped; the debugging story belongs in the PR. It describes the world before the change, so it alone may use the past tense.
- **Keep bodies concise**: 1–4 bullets, each one compact line of ~100 characters at most — trim a longer bullet, or when trimming would drop what it says, wrap it onto a line indented two spaces; omit the body entirely for simple changes. If the user explicitly staged a large changeset to go in a single commit, the body may exceed 4 bullets — but never more than 6, a hard cap with no exceptions; each bullet stays short, plain, and readable. When 6 isn't enough, summarize at a higher level rather than enumerating.
- **Plain sentence mechanics**, the slice of Simplified Technical English that fits a bullet quoting identifiers: active voice with the code as the subject (`parse` returns an empty string for null, not "an empty string is now returned"); one change per bullet, and one tense across the message, either what the code now does or the action taken, not both; no bullet opens with an -ing word; no hedges (should, may, might, probably), because a commit records what changed and doubt belongs in the PR; no vague openers (improve, clean up, tweak, various), name the thing instead; one name for one thing across the message. The lint warns on the three of these it can see.

## Workflow

### 1. Preflight and mode detection — run the detector

Run `bash <skill-base-dir>/scripts/commit-preflight.sh` (the skill's base
directory is announced when this skill loads). One call replaces the manual
status/log/conflict checks and emits: clean-tree and conflict aborts, the
mode (single vs grouped), recent subjects (match their scope naming and
tone), staged/unstaged/untracked stats, an oversized-diff warning, and — when
the change spans paths — an informational file-spread summary. Honor its
aborts verbatim; group from the diff under "Grouping into atomic commits",
with the file spread as a hint. With `--amend`, skip the preflight and go to
the **Amend workflow** below: its clean-tree stop would end a message-only
amend before it starts.

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
   names; in single mode leave off `--` and the paths. The gate leaves
   nothing committed and nothing staged on these exits; rewrite the flagged
   lines in the echoed file and run `--commit` again:
   - **Exit 1, LINT FAIL**: the message breaks a rule.
   - **Exit 2, LINT WARN**: fix each warned line. Add `--accept-warnings`
     right after the message file, before `--`, only when every warning
     misreads its line (a noun ending in -ing).
3. Verify with `git log -1 --oneline`. Grouped: move to the next group. Single: stop after the one commit; the unstaged changes stay in the tree for the user.

### 4. Summary

Show `git log --oneline -n <commits made>` and confirm state with `git status`. In grouped mode, give each commit one line: its subject and the pass that formed it, such as `bound: a rename and its call sites`, `separate: its own symptom`, or `weighed: 180 lines, one sitting`; say which changes a shared source file joined. When a commit's code uses a file that is still untracked, name that file: the commit stands only once the user adds it.

## Amend workflow (`--amend` — interactive)

1. Show current state — file context BEFORE the message so the AskUserQuestion prompt doesn't push it out of view: `git diff --cached --stat` (staged, folds in only with staged changes), `git diff --stat` (unstaged, will NOT be included), then `git log -1 --format='%H%n%s%n%n%b'`.
2. AskUserQuestion: "Amend message only" / "Amend with staged changes" / "Cancel". Message only leaves anything staged in place.
3. Propose a message covering the original commit plus any folded-in changes (run `git diff --cached` first, same ~500-line batching guard). Write it to a `mktemp` file and lint it with `bash <skill-base-dir>/scripts/commit-preflight.sh --lint <file>`; fix every LINT FAIL line and every LINT WARN line except one that misreads its line, then AskUserQuestion: "Accept and amend" / "Edit message" / "Cancel".
4. Write any edit the user made into the file, then amend through the gate: `bash <skill-base-dir>/scripts/commit-preflight.sh --commit <file> --amend`, with no `--` or paths, since the amend takes the index as confirmed in step 2. For a message-only amend, add `--message-only` after `--amend`: the gate rewords the commit and leaves the index as it is. On exit 1 or 2, fix the flagged lines and run it again, as for any commit. Verify with `git log -1 --oneline`. If the branch tracks a remote, warn that updating it requires a force-push.

## Guardrails

- Never force push or use destructive git commands; never bypass hooks with `--no-verify` unless explicitly requested
- Pre-commit hook failure: show the full hook output, fix auto-fixable issues (lint/format) with Edit, and rerun the same `--commit` call once; grouped mode stages nothing, since the named paths carry the fixed files, and single mode re-stages only the files the hook flagged, stopping to report instead when a flagged file has unstaged hunks. If it fails again the same way, stop and report
- Commit-msg hook rejection: the same message cannot pass twice, so read the hook's output (and its source, if the rule is not stated), rewrite the subject to the rule it enforces, re-lint, and retry once; if it rejects again, stop and show both messages with the hook output
- Every commit and amend goes through the gate and takes its files from it: named paths in grouped mode, the user's index in single and amend mode; `git add -A`, `-u`, and `.` are never used, even when the tree holds nothing else
- Respect the user's staging selection — if they staged specific files, commit exactly those
- Grouping is your judgment under "Grouping into atomic commits"; make every grouping call yourself, since a commit split one way or another is cheap to live with

Execute this workflow now, starting with preflight.
