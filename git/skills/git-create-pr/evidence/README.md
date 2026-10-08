# Evidence

Recorded runs that back the claims in the skill's README. Each case is one branch of real commits opened as a pull request two ways, by a bare agent and by the same agent running this skill, with the resulting title and body quoted as GitHub stored them. Cases are numbered and stand on their own; nothing in them depends on where the input came from. These are comparisons to read and judge, not tests with a pass or fail; the method below is enough to rerun any of them.

| Case | Claim | Result |
|---|---|---|
| [0001](0001.md) | The body is written from the diff, for a reviewer, with concrete testing items and no provenance | bare wrote from commit messages with one generic test item and a tool footer; skill read the diff and wrote file-level changes, an impact note, and five checkable items |
| [0002](0002.md) | Impact appears only when there is a consequence to weigh | bare used its fixed shape again; skill omitted Impact for a figures-only fix and kept Testing to what the diff supports |

## Method

| Item | Value |
|---|---|
| Date | 2026-10-08 |
| Model, every arm | `claude-sonnet-5-5` |
| Harness | Claude Code 2.1.293, `claude -p`, `--setting-sources project`, `--permission-mode acceptEdits`, `--allowedTools` limited to git, gh, bash, read-only shell commands, Read, Glob, Grep, Edit |
| Skill under test | this folder's parent, at commit `8f85865`, loaded with `--plugin-dir` as plugin `eval`, so it is the repo copy rather than an installed one |
| Bare prompt | `Open a pull request for this branch against <base>.` |
| Skill prompt | `/eval:git-create-pr <base>` |
| Visible to both arms | the fixture repo's own `CLAUDE.md` or `AGENTS.md`, and Claude Code's standing reminder to end PR descriptions with a robot-emoji "Generated with" line |
| Hidden from both arms | user-level `CLAUDE.md`, user skills, user hooks; verified by asking the bare arm to list its skills and any commit rule it could see |

**Input state.** A case is a real change set from a real project: the commits of a merged pull request, on a branch of their own, against a base branch pinned at the change set's original branch point. Both arms get a branch each at the same commits, so the merge-base diff is identical. The remote is a private throwaway repository holding only the base branches; each arm pushes its own branch and opens its own PR. The repo has no PR template, and its history titles commits conventionally.

**What is compared.** Whether the agent read the diff or only the commit messages, the title and its style, the body's sections, whether Testing items name real commands, paths, or behaviors from the diff, whether an Impact section appears only when the change carries a consequence, any provenance footer, whether the push was plain and the base correct, and the turn count and cost the harness reported. The body of the original pull request is not an arm: it was written with an earlier version of the skill and an unrecorded model.

**Rerunning.** Any merged change set works as a new case: fetch its head, create a base branch at its branch point on a throwaway remote, check out the commits on a fresh branch, and run each arm from inside it with the flags in the table. Transcripts come from `--output-format stream-json --verbose`; they are not committed here because each is 30 to 60 KB of JSON, but every number in a case file was read from one.
