# Evidence

Recorded runs that back the claims in the skill's README. Each case is one dirty working tree committed by the agent running this skill, and usually by a bare agent too, with the commits quoted as `git log` prints them, newest first. A case that tests only the skill's own behavior (0003, 0005) runs the skill arm alone and says so. Cases are numbered and stand on their own; nothing in them depends on where the input came from. These are comparisons to read and judge, not tests with a pass or fail; the method below is enough to rerun any of them.

| Case | Claim | Result |
|---|---|---|
| [0001](0001.md) | A single-intent tree stays one commit with its docs; the body is bullets led by `Why:` when the change has a cause from outside the code, never provenance | both arms make one commit; bare's prose names the cause, the skill ends on the symptom with no `Why:` in this run, and no trailer |
| [0002](0002.md) | One intent across code, docs, and packaging stays one commit, and `Why:` carries the measured figure | both arms make one commit of nine files; the skill's `Why:` gives the measured and the listed sizes |
| [0003](0003.md) | A repo's own subject format outranks the skill's `type(scope)` stance | skill writes `WID-5: …` with the README in the same commit, its lint skips the format check, the repo's hook passes first try |
| [0004](0004.md) | A branch whose parts share files splits by type, then by "the same fix or a different one" | bare makes one commit of fourteen files; skill makes two `fix` commits, typing the watchdog as a fix where the branch called it a feature |
| [0005](0005.md) | Across repeated runs, `Why:` appears when a change has an outside cause, and grouping follows type and the same-or-different test | skill arm only, fourteen fixtures three times each: `Why:` 31/33, grouping 42/42 on the current skill |

## Method

| Item | Value |
|---|---|
| Date | 2026-10-27, every case |
| Model, every arm | `claude-sonnet-5-5` |
| Harness | Claude Code 2.1.299, `claude -p`, `--setting-sources project`, `--permission-mode acceptEdits`, `--allowedTools` set to `Bash(git:*)`, `Bash(bash:*)`, `Bash(printf:*)`, `Bash(cat:*)`, `Bash(head:*)`, `Bash(tail:*)`, `Bash(ls:*)`, `Bash(wc:*)`, `Bash(grep:*)`, `Bash(echo:*)`, Read, Glob, Grep, Edit |
| Skill under test | this folder's parent, as committed with this evidence, copied into a scratch plugin and loaded with `--plugin-dir` as plugin `eval`, so it is the repo copy rather than an installed one. Four wording edits came after the runs: the shared-code-file question, single mode stopping after its one commit, step 1 pointing at the grouping section, and the 8-bullet cap read as "at most 8" |
| Bare prompt | `Commit the changes.` |
| Skill prompt | `/eval:git-commit` |
| Run order | case skill arms one at a time, alongside the 0005 probe runs, which slows their wall times; bare arms in parallel, each in its own clone |
| Visible to both arms | the fixture repo's own `CLAUDE.md` or `AGENTS.md` and the docs they link, and Claude Code's standing reminder to end commit messages with a `Co-Authored-By` line |
| Hidden from both arms | user-level `CLAUDE.md`, user skills, user hooks; verified by asking a bare arm to list its skills and any commit rule it could see |

**Input state.** A case is a real change set from a real project, rebuilt as the moment before any commit existed: a clone with its remote removed, checked out at the branch's head, then `git reset --mixed <branch point>`, so every change is a tracked, unstaged modification. A file the branch added is marked with `git add -N` so it counts as tracked too. Each arm gets its own clone of the identical tree, and with no remote nothing can be pushed. A case may instead be a small fixture built by hand; its file says so and lists the exact contents. Each case file describes its own input, and nothing in the method depends on which project it came from.

**What is compared.** Number of commits and which files each took, the subject, the body shape, whether a body leads with `Why:`, any provenance trailer, whether the agent staged by name or with `-A`, whether it asked a question, and the turn count and cost the harness reported. The history those changes were originally committed with is not an arm: it was made over time with an earlier version of the skill and an unrecorded model.

**Rerunning.** Any merged change set works as a new case: build its clones as above, and run each arm from inside its clone with the flags in the table. Transcripts come from `--output-format stream-json --verbose`; they are not committed here because each is 20 to 150 KB of JSON, but every number in a case file was read from one.
