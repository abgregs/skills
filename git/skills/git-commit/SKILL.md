---
name: git-commit
description: Generate conventional commit messages and execute commits autonomously. Use when the user is committing code or asks for a commit message. Commits staged changes as one commit (single mode), splits unstaged changes into logical commits (grouped mode), or interactively amends the last commit (--amend).
argument-hint: "Optional — commit type, flags, or --amend"
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, Edit
---

You are creating git commits with well-crafted conventional commit messages.

**Execution mode**: autonomous for the normal flow — do not prompt to confirm mode, groupings, or messages, the one question being the shared-code-file case under "Grouping into atomic commits"; decide and execute until the mode's changes are committed (untracked files are left alone). Amend mode (`--amend`) is interactive.

## Message requirements

- Conventional format: `type(scope): description` — types: feat, fix, refactor, docs, test, chore, build, ci, perf, style; scope = area affected (e.g. api, auth, ui, config). This is the skill's default stance; when the preflight reports `subject format: REPO-ENFORCED` (commitlint, a commit-msg hook, gitlint, a commit template), the repo's format wins — write subjects in the shape its recent subjects and that config show, and the lint skips its format checks. Every commit from one run carries the identifier the work already has (a ticket or issue id); a split reuses it rather than taking a new one
- Subject line under 72 characters, ASCII only (so no emojis); no brackets or parentheses in the description, the `type(scope):` prefix being the only pair. Ordinary punctuation such as `/`, `:` or `-` is fine, and this is exactly what the lint checks
- **The message carries the change, never its provenance.** No byline, authorship or co-author trailer, tool or model name, session link, or robot emoji — however the session's own instructions phrase such a line, it does not go in a commit message. Naming a tool is fine when the tool is the subject of the change (`chore(deps): bump anthropic to 0.42`); what stays out is any claim about who composed the work.
- Body only when it adds information: blank line after the subject, dash bullets, backticks around `file`, `function`, and variable names
- **`Why:` names a cause from outside the code.** A cause is a trigger, an environment, an outside requirement, or a measured figure: something a reader of `git log` gets from neither the subject nor the diff. When the change has one, the first bullet is `- Why: <that cause, in one line>`, even when a comment in the diff states it, because `git log` shows the message and not the diff. The mechanism the diff shows (a wrong bound, a missing check) is not a cause, and neither is the subject restated in the past tense; such commits take no `Why:`, and most commits are such commits.
  - `fix(auth): expire refresh tokens on password change` takes no `Why:`. "Tokens outlived a password change" restates the subject.
  - `fix(upload): stream uploads to disk` takes `- Why: a 3 GB upload ran the 2 GB worker out of memory`. "The whole file was read into memory" is the mechanism, not the cause.

  `docs`, `chore`, and `test` commits never take one, and the lint fails a message that breaks this or puts `Why:` anywhere but first. Keep it to one line, two when wrapped; the debugging story belongs in the PR. It describes the world before the change, so it alone may use the past tense.
- **Keep bodies concise**: 2–4 bullets, each one compact line of ~100 characters at most — trim a longer bullet, or when trimming would drop what it says, wrap it onto a line indented two spaces; omit the body entirely for simple changes. If the user explicitly staged a large changeset to go in a single commit, the body may exceed 4 bullets — but never more than 8, a hard cap with no exceptions; each bullet stays short, plain, and readable. When 8 isn't enough, summarize at a higher level rather than enumerating.
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
with the file spread as a hint.

Mode: `--amend` argument → **Amend workflow** below. Otherwise the preflight
report states the mode: staged changes exist → **single mode** (one commit
for the staged changes only); only unstaged changes → **grouped mode**
(split into logical commits).

### 2. Analyze changes

- Single: `git diff --cached --stat`, then `git diff --cached`
- Grouped: `git diff --stat`, `git diff`, and `git status` for untracked files, then group into atomic commits as below
- Either mode: if the diff exceeds ~500 lines, read it in batches by path or file type (e.g. `git diff -- 'src/'`) instead of all at once

**Grouping into atomic commits.** Each commit is one change of one type. Work it out in two passes:

1. **Type is the seam.** Label each piece of the diff with the conventional type of the change it serves. A `feat` gives the user a capability they did not have; a `fix` restores behavior that was meant to work; the other types mean what their names say. Tests, docs, and changelog lines take the type of the change they serve, so `test` and `docs` are for work that serves nothing else. Pieces of different types never share a commit: a fix and a feature are two commits, even when one incident prompted both.
2. **Same change or a different one.** Within one type, ask of each pair of pieces: is this the same fix, or a different fix? The same feature, or another? Two fixes are different when each repairs its own symptom and either could be undone while keeping the other. A piece that only completes another is the same change: a rename and its call sites, a dependency bump and the code adapted to its new API, a migration and the model that needs it. Size never decides a split, and scope is a hint, since one fix can span `audio` and `session`.

Commit in dependency order, each change after the changes it needs: a refactor that makes room for a feature lands before the feature. Staging is by path, so a doc or changelog that serves two commits goes in the last of them. When one code file holds pieces of two commits, ask, because staging it whole lands the earlier commit without code it needs.

### 3. Commit — no approval prompts

Grouped mode first prints a one-line overview per planned group, then processes groups in order, staging each by naming its paths: `git add <file> <file>`, never `git add -A`, `-u`, or `.`. A path list is what keeps untracked files and the other groups' files out of the commit; a sweep only looks equivalent on the day nothing else is in the tree. Use `git restore --staged .` beforehand only if the run began with nothing staged.

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
   bash <skill-base-dir>/scripts/commit-preflight.sh --commit "$msg"
   ```
   Every commit goes through `--commit`, each message in its own `mktemp`
   file, so two sessions committing at once never share a message. The gate
   leaves nothing committed on these exits; rewrite the flagged lines in the
   echoed file and run `--commit` again:
   - **Exit 1, LINT FAIL**: the message breaks a rule.
   - **Exit 2, LINT WARN**: fix each warned line. Add `--accept-warnings`
     after the path only when every warning misreads its line (a noun ending
     in -ing).
3. Verify with `git log -1 --oneline`. Grouped: move to the next group. Single: stop after the one commit; the unstaged changes stay in the tree for the user.

### 4. Summary

Show `git log --oneline -n <commits made>` and confirm state with `git status`.

## Amend workflow (`--amend` — interactive)

1. Show current state — file context BEFORE the message so the AskUserQuestion prompt doesn't push it out of view: `git diff --cached --stat` (newly staged, will fold in), `git diff --stat` (unstaged, will NOT be included), then `git log -1 --format='%H%n%s%n%n%b'`.
2. AskUserQuestion: "Amend message only" / "Amend with staged changes" / "Cancel". If message-only is chosen while changes are staged, warn that `git commit --amend` would include them and confirm unstage-first vs include.
3. Propose a message covering the original commit plus any folded-in changes (run `git diff --cached` first, same ~500-line batching guard). AskUserQuestion: "Accept and amend" / "Edit message" / "Cancel".
4. Execute `git commit --amend` via heredoc and verify with `git log -1 --oneline`. If the branch tracks a remote, warn that updating it requires a force-push.

## Guardrails

- Never force push or use destructive git commands; never bypass hooks with `--no-verify` unless explicitly requested
- Pre-commit hook failure: show the full hook output, keep files staged, fix auto-fixable issues (lint/format) with Edit, re-stage, retry the same message through `--commit` once; if it fails again the same way, stop and report
- Commit-msg hook rejection: the same message cannot pass twice, so read the hook's output (and its source, if the rule is not stated), rewrite the subject to the rule it enforces, re-lint, and retry once; if it rejects again, stop and show both messages with the hook output
- Stage by path in every mode; `git add -A`, `-u`, and `.` are never used, even when the tree holds nothing else
- Respect the user's staging selection — if they staged specific files, commit exactly those
- Grouping is your judgment under "Grouping into atomic commits"; ask only in the shared-file case it names

Execute this workflow now, starting with preflight.
