---
name: git-commit
description: Generate conventional commit messages and execute commits autonomously. Use when the user is committing code or asks for a commit message. Commits staged changes as one commit (single mode), splits unstaged changes into logical commits (grouped mode), or interactively amends the last commit (--amend).
argument-hint: (optional commit type, flags, or --amend)
allowed-tools: Bash, Read, Glob, Grep, AskUserQuestion, Edit
---

You are creating git commits with well-crafted conventional commit messages.

**Execution mode**: autonomous for the normal flow — do not prompt to confirm mode, groupings, or messages; decide and execute until no tracked changes remain (untracked files are left alone). Amend mode (`--amend`) is interactive.

## Message requirements

- Conventional format: `type(scope): description` — types: feat, fix, refactor, docs, test, chore, build, ci, perf, style; scope = area affected (e.g. api, auth, ui, config)
- Subject line under 72 characters; no emojis, no Claude references, no parentheses or other special characters in the description (beyond the `type(scope):` prefix)
- Body only when it adds information: blank line after the subject, dash bullets, backticks around `file`, `function`, and variable names
- **Keep bodies concise**: 2–4 bullets, each one compact line — trim any bullet pushing past ~72 characters, and omit the body entirely for simple changes. If the user explicitly staged a large changeset to go in a single commit, more bullets (5+) are acceptable, but each stays short, plain, and readable.

## Workflow

### 1. Preflight and mode detection

Run in parallel: `git status --porcelain` and `git log --oneline -5` (match the branch's existing scope naming and tone).

Abort if:
- Nothing to commit (empty status, or only `??` lines) → say "Nothing to commit — working tree is clean." and stop
- Unresolved conflicts (lines starting `UU`, `AA`, `DD`, `AU`, `UA`, `DU`, `UD`) → list the conflicting files and stop

Mode: `--amend` argument → **Amend workflow** below. Staged changes exist → **single mode**: one commit for the staged changes only. Only unstaged changes → **grouped mode**: split into logical commits.

### 2. Analyze changes

- Single: `git diff --cached --stat`, then `git diff --cached`
- Grouped: `git diff --stat`, `git diff`, and `git status` for untracked files; group by related functionality, same module/directory, or same change type; order foundational changes before dependent ones
- Either mode: if the diff exceeds ~500 lines, read it in batches by path or file type (e.g. `git diff -- 'src/'`) instead of all at once

### 3. Commit — no approval prompts

Grouped mode first prints a one-line overview per planned group, then processes groups in order, staging each with `git add <files>` (use `git restore --staged .` beforehand only if the run began with nothing staged).

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
2. Execute with heredoc for multi-line support:
   ```bash
   git commit -m "$(cat <<'EOF'
   type(scope): description

   - Detail 1
   EOF
   )"
   ```
3. Verify with `git log -1 --oneline`. Grouped: move to the next group. Single: re-run `git status --porcelain`; if tracked changes remain (ignore `??` lines), loop from step 1 until clean.

### 4. Summary

Show `git log --oneline -n <commits made>` and confirm state with `git status`.

## Amend workflow (`--amend` — interactive)

1. Show current state — file context BEFORE the message so the AskUserQuestion prompt doesn't push it out of view: `git diff --cached --stat` (newly staged, will fold in), `git diff --stat` (unstaged, will NOT be included), then `git log -1 --format='%H%n%s%n%n%b'`.
2. AskUserQuestion: "Amend message only" / "Amend with staged changes" / "Cancel". If message-only is chosen while changes are staged, warn that `git commit --amend` would include them and confirm unstage-first vs include.
3. Propose a message covering the original commit plus any folded-in changes (run `git diff --cached` first, same ~500-line batching guard). AskUserQuestion: "Accept and amend" / "Edit message" / "Cancel".
4. Execute `git commit --amend` via heredoc and verify with `git log -1 --oneline`. If the branch tracks a remote, warn that updating it requires a force-push.

## Guardrails

- Never force push or use destructive git commands; never bypass hooks with `--no-verify` unless explicitly requested
- Pre-commit hook failure: show the full hook output, keep files staged, fix auto-fixable issues (lint/format) with Edit, re-stage, retry the same message once; if it fails again the same way, stop and report
- Respect the user's staging selection — if they staged specific files, commit exactly those
- Grouping is your judgment; ask only when a split is genuinely ambiguous in a way that affects correctness (e.g. unrelated features tangled in one file)

Execute this workflow now, starting with preflight.
