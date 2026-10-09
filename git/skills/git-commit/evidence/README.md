# Evidence

Recorded runs that back the claims in the skill's README. Each case is one dirty working tree committed by the agent running this skill, and usually by a bare agent too, with the commits quoted as `git log` prints them, newest first. A case that tests only whether the skill defers (0003) runs the skill arm alone and says so. Cases are numbered and stand on their own; nothing in them depends on where the input came from. These are comparisons to read and judge, not tests with a pass or fail; the method below is enough to rerun any of them.

| Case | Claim | Result |
|---|---|---|
| [0001](0001.md) | Bodies are bullets, never provenance; a single-intent tree stays one commit | bare and skill agree on one commit; bare adds prose and a trailer, skill adds bullets and no trailer |
| [0002](0002.md) | A multi-intent tree is split by intent | bare makes one commit of nine files; skill makes two, code-and-user-facing vs internal docs |
| [0003](0003.md) | A repo's own subject format outranks the skill's `type(scope)` stance | skill writes `WID-5: …`, its lint skips the format check, the repo's hook passes first try |

## Method

| Item | Value |
|---|---|
| Date | 2026-10-07 (0001, 0002), 2026-10-08 (0003) |
| Model, every arm | `claude-sonnet-5-5` |
| Harness | Claude Code 2.1.293, `claude -p`, `--setting-sources project`, `--permission-mode acceptEdits`, `--allowedTools` limited to git, bash, read-only shell commands, Read, Glob, Grep, Edit |
| Skill under test | this folder's parent, at commit `817d9c9`, loaded with `--plugin-dir` as plugin `eval`, so it is the repo copy rather than an installed one |
| Bare prompt | `Commit the changes.` |
| Skill prompt | `/eval:git-commit` |
| Visible to both arms | the fixture repo's own `CLAUDE.md` or `AGENTS.md`, and Claude Code's standing reminder to end commit messages with a `Co-Authored-By` line |
| Hidden from both arms | user-level `CLAUDE.md`, user skills, user hooks; verified by asking the bare arm to list its skills and any commit rule it could see |

**Input state.** A case is a real change set from a real project, rebuilt as the moment before any commit existed: a detached worktree at the branch point with `git reset --mixed <head>` applied, so every change is a tracked, unstaged modification. Both arms start from the identical tree. The clone has no remote, so nothing can be pushed. A case may instead be a small fixture built by hand; its file says so and lists the exact contents. Each case file describes its own input, and nothing in the method depends on which project it came from.

**What is compared.** Number of commits and which files each took, the subject, the body shape, any provenance trailer, whether the agent staged by name or with `-A`, whether it asked a question, and the turn count and cost the harness reported. The history those changes were originally committed with is not an arm: it was made over time with an earlier version of the skill and an unrecorded model.

**Rerunning.** Any merged change set works as a new case: fetch its head, make the worktree as above, and run each arm from inside it with the flags in the table. Transcripts come from `--output-format stream-json --verbose`; they are not committed here because each is 30 to 50 KB of JSON, but every number in a case file was read from one.
