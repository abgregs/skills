# Evidence

Recorded runs that back the claims in the skill's README. Each case is one dirty working tree committed by the agent running this skill, and usually by a bare agent too, with the commits quoted as `git log` prints them, newest first. A case that tests only the skill's own behavior (0003, 0005) runs the skill arm alone and says so. Cases are numbered and stand on their own; nothing in them depends on where the input came from. These are comparisons to read and judge, not tests with a pass or fail; the method below is enough to rerun any of them.

| Case | Claim | Result |
|---|---|---|
| [0001](0001.md) | A single-intent tree stays one commit with its docs; the body is bullets led by `Why:` when the change has a cause from outside the code, never provenance | both arms make one commit; three of four skill runs lead with a `Why:` naming the trigger, bare names none, and no skill run has a trailer |
| [0002](0002.md) | One intent across code, docs, and packaging stays one commit, and `Why:` carries the measured figure | both arms make one commit of nine files; the skill's `Why:` gives the listed and the measured size |
| [0003](0003.md) | A repo's own subject format outranks the skill's `type(scope)` stance | skill writes `WID-5: …` with the README in the same commit, its lint skips the format check, the repo's hook passes first try |
| [0004](0004.md) | A branch whose parts share files separates by type and outcome, and changes that share a source file commit together | both arms make one commit of fourteen files; the skill finds two fixes and says it joined them because one file holds code for both |
| [0005](0005.md) | Across repeated runs, `Why:` appears when a change has an outside cause, and grouping follows the skill's rules for binding, separating, and close calls | skill arm only, nineteen fixtures three times each: `Why:` 39/39 and grouping 51/51 on the current skill; the close call stays one commit at 20 lines and splits in three at 1,048 |
| [0006](0006.md) | Changes that each stand alone split, and one purpose across several files stays one commit when one sitting can review it | the skill makes three commits, keeping 149 lines of gap tests as one; bare makes two |

## Not covered

The README describes behavior no recorded run exercises yet:

- Single mode: every case starts with nothing staged.
- A `LINT FAIL` and its rewrite, a `commit-msg` hook that rejects the first message, and a pre-commit hook failure. The only gate stops on record are the two `LINT WARN`s in 0004.
- Repo-enforced formats other than a `commit-msg` hook set through `core.hooksPath`: commitlint, gitlint, lefthook, pre-commit, `commit.template`.
- A split that carries one ticket id into each of its commits.
- Untracked files beside the change, and a summary naming an untracked file a commit's code needs: no case tree has any.
- A shared source file that joins a fix and a feature, so the type order decides; 0004 joins two fixes.
- A test or doc file that covers two commits and goes in the later code commit; the probe's shared changelog (H6, H7) is the only such file on record.
- Amend mode, and `--accept-warnings` for a warning that misreads its line.

## Method

| Item | Value |
|---|---|
| Date | cases 0001 to 0004 and 0006, both arms, and probe round 9: 2026-11-02. Probe rounds 1 to 5: 2026-10-27; rounds 6 to 8: 2026-10-30 to 2026-11-02 |
| Model, every arm | `claude-sonnet-5-5` |
| Harness | Claude Code 2.1.299, `claude -p`, `--setting-sources project`, `--permission-mode acceptEdits`, `--allowedTools` set to `Bash(git:*)`, `Bash(bash:*)`, `Bash(printf:*)`, `Bash(cat:*)`, `Bash(head:*)`, `Bash(tail:*)`, `Bash(ls:*)`, `Bash(wc:*)`, `Bash(grep:*)`, `Bash(echo:*)`, Read, Glob, Grep, Edit |
| Skill under test | this folder's parent, as committed with this evidence, copied into a scratch plugin and loaded with `--plugin-dir` as plugin `eval`, so it is the repo copy rather than an installed one. Every case arm and probe round 9 ran on `SKILL.md` and `scripts/` as committed; rounds 1 to 8 ran on the earlier states 0005 lists |
| Bare prompt | `Commit the changes.` |
| Skill prompt | `/eval:git-commit` |
| Run order | case skill arms one at a time and bare arms in parallel, each in its own clone, all alongside probe round 9, which slows their wall times; then the three extra 0001 skill runs in parallel. The 0003 and 0006 skill arms failed to authenticate on their first start, did nothing, and ran again alone at the end |
| Visible to both arms | the fixture repo's own `CLAUDE.md` or `AGENTS.md` and the docs they link, and Claude Code's standing reminder to end commit messages with a `Co-Authored-By` line |
| Hidden from both arms | user-level `CLAUDE.md`, user skills, user hooks. `--setting-sources project` does not hide the user's global `~/.claude/CLAUDE.md`, so it was moved aside for these runs and restored after. A bare arm asked, before any other run, to list its skills and any commit rule it could see named only the repo's `AGENTS.md`, the harness reminder, and built-in skills. Probe rounds 6 to 8 ran with that file visible: it holds the user's general working rules and "Always commit changes using the `/git-commit` skill". Whether rounds 1 to 5 saw it is not known; their transcripts are gone |

**Input state.** A case is a real change set from a real project, rebuilt as the moment before any commit existed: a clone with its remote removed, checked out at the branch's head, then `git reset --mixed <branch point>`, so every change is a tracked, unstaged modification. A file the branch added is marked with `git add -N` so it counts as tracked too. Each arm gets its own clone of the identical tree, and with no remote nothing can be pushed. A case may instead be a small fixture built by hand; its file says so and lists the exact contents. Each case file describes its own input, and nothing in the method depends on which project it came from.

**What is compared.** Number of commits and which files each took, the subject, the body shape, whether a body leads with `Why:`, any provenance trailer, whether the agent staged by name or with `-A`, whether it asked a question, and the turn count and cost the harness reported. The history those changes were originally committed with is not an arm: it was made over time with an earlier version of the skill and an unrecorded model.

**Rerunning.** Any merged change set works as a new case: build its clones as above, and run each arm from inside its clone with the flags in the table. Transcripts come from `--output-format stream-json --verbose`; they are not committed here because each is 20 to 150 KB of JSON, but every number in a case file was read from one.
