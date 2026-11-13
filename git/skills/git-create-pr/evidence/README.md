# Evidence

Recorded runs that back the claims in the skill's README. Each case is one branch of real commits opened as a pull request two ways, by a bare agent and by the same agent running this skill, with the resulting title and body quoted as GitHub stored them. Cases are numbered and stand on their own; nothing in them depends on where the input came from. These are comparisons to read and judge, not tests with a pass or fail; the method below is enough to rerun any of them.

| Case | Claim | Result |
|---|---|---|
| [0001](0001.md) | The body is written from the diff, for a reviewer, with concrete testing items and no provenance | bare wrote from commit messages with one generic test item and a tool footer; skill read the diff and wrote file-level changes, an impact note, and five checkable items |
| [0002](0002.md) | Impact appears only when there is a consequence to weigh | bare used its fixed shape again; skill omitted Impact for a figures-only fix and kept Testing to what the diff supports |
| [0003](0003.md) | A change that moves structure ends Summary with one Mermaid diagram; a warned line stops the PR until it is rewritten | bare wrote from commit messages and drew nothing; skill read the diff by path, drew the new capture path as a ten-node flowchart, and fixed two lint warnings before opening |
| [0004](0004.md) | A small change to the order of calls across threads gets a sequence diagram | both arms read the diff; skill drew the fixed order of the two threads, but not the racing order before it |
| [0005](0005.md) | A change inside one function gets no diagram; an update keeps the lines people added in GitHub | neither arm drew one; on the update, skill rewrote the body and kept a ticked box, `Closes #1`, and a screenshot; bare kept them by not editing at all |

## Not covered

The README describes behavior no recorded run exercises yet:

- A `Verified:` section: no run had a check that ran, in the session or reported by the user, so every Testing list is reviewer items only.
- A repo PR template, one or several.
- A `[conflict]` abort, a `[stale]` base, or `[deleted]` files.
- A pre-push hook failure, and an open PR whose base differs from the one asked for.
- A diff that changes something a person sees, so the screenshot step names its spots.
- An update after new commits, and an update where a bare agent rewrites the body; in 0005 bare left an up-to-date body alone.
- Whether GitHub renders the diagrams in 0003 and 0004; no run checked, and the lint cannot.
- `--accept-warnings`, for a warning that misreads its line.

## Method

| Item | 0001–0002 | 0003–0005 |
|---|---|---|
| Date | 2026-10-08 | 2026-11-12 |
| Model, every arm | `claude-sonnet-5-5` | `claude-sonnet-5-5` |
| Harness | Claude Code 2.1.293 | Claude Code 2.1.322 |
| Skill under test | this folder's parent at commit `8f85865`, before Testing split into `Verified:` and `For the reviewer:` and before the clarity warnings | this folder's parent with the diagram rule, update-keep lines, the conflict abort, and blocking warnings, run from the working tree on top of `f817de6`. Two later changes postdate these runs: the Summary rule that leads with the problem, and the ship gate, which replaced the separate `--lint` and `gh` calls quoted in the cases |
| User's global `CLAUDE.md` | not known to be hidden: `--setting-sources project` does not hide it, which was found after these runs | moved aside for the runs and restored after |

Every arm ran `claude -p` with `--setting-sources project`, `--permission-mode acceptEdits`, and `--allowedTools` limited to git, gh, bash, mktemp, read-only shell commands, Read, Glob, Grep, Edit. The skill under test was copied into a scratch plugin and loaded with `--plugin-dir` as plugin `eval`, so it is the repo copy rather than an installed one.

| Prompt | Value |
|---|---|
| Bare | `Open a pull request for this branch against <base>.` |
| Skill | `/eval:git-create-pr <base>` |
| Bare update (0005) | `Update the description of the open pull request for this branch.` |
| Skill update (0005) | `/eval:git-create-pr <base>` |

**Visible to both arms.** The fixture repo's own `CLAUDE.md` and `AGENTS.md`, the docs they link, and Claude Code's standing reminder to end PR descriptions with a robot-emoji "Generated with" line. The repo's `docs/conventions/git.md` gives a PR skeleton with `## Scope` and `## Changes Made`; bare followed it in 0003 to 0005, and the skill used its own shape. A bare arm asked, before the 0003–0005 runs, to list its skills and any PR instruction it could see named only built-in skills, the harness reminder, and the repo's `AGENTS.md`.

**Hidden from both arms.** User-level skills and hooks.

**Input state.** A case is a real change set from a real project: the commits of a merged pull request, on a branch of their own, against a base branch pinned at the change set's original branch point. Each arm gets a clone of its own on a branch of its own at the same commits, so the merge-base diff is identical. The remote is a private throwaway repository holding the base branches and the arms' branches; each arm pushes its own branch and opens its own PR. The repo has no PR template, and its history titles commits conventionally. In 0003–0005 the six arms pushed to the remote at once, which made one push fail and retry (0005 bare) and printed pack errors on another (0004 skill); every PR holds its full commits and diff. Run the pushes one at a time to avoid it.

**What is compared.** Whether the agent read the diff or only the commit messages, the title and its style, the body's sections, whether Testing items name real commands, paths, or behaviors from the diff, whether an Impact section appears only when the change carries a consequence, whether a diagram appears and what it draws, what an update keeps, any provenance footer, whether the push was plain and the base correct, and the turn count and cost the harness reported. The body of the original pull request is not an arm: it was written with an earlier version of the skill and an unrecorded model.

**Rerunning.** Any merged change set works as a new case: fetch its head (for a squash-merged PR, `pull/<n>/head`), create a base branch at its branch point on a throwaway remote, check out the commits on a fresh branch, and run each arm from inside it with the flags above. Transcripts come from `--output-format stream-json --verbose`; they are not committed here because each is 30 to 150 KB of JSON, but every number in a case file was read from one.
