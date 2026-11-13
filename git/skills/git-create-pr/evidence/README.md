# Evidence

Recorded runs that back the claims in the skill's README. Each case is one branch of real commits opened as a pull request two ways, by a bare agent and by the same agent running this skill, with the resulting title and body quoted as GitHub stored them; 0006 runs the skill alone, on a PR an earlier run opened. Cases are numbered and stand on their own; nothing in them depends on where the input came from. These are comparisons to read and judge, not tests with a pass or fail; the method below is enough to rerun any of them. Everything above History describes runs of the skill as it now stands; History summarizes the earlier ones that shaped the rules.

| Case | Claim | Result |
|---|---|---|
| [0001](0001.md) | The body is written from the diff for a reviewer: the problem first, per-file changes, checkable testing items, no provenance | both arms read the diff this time and wrote per-file changes; the skill's Summary states the bug, its cause, and the fix in that order, where bare's opens on "no longer swallows" and leaves the cause to Impact; only bare ended with a tool footer |
| [0002](0002.md) | Impact appears only when there is a consequence to weigh, and a change a person sees gets its screenshot spot named | bare read only the commit messages; the skill read the diff, left Impact out of a figures-only fix, and named the picker as the one screenshot spot |
| [0003](0003.md) | A change that moves structure ends Summary with one Mermaid diagram | bare drew nothing; the skill led with the call-mode problem and drew the new capture path as a nine-node flowchart |
| [0004](0004.md) | A change that reorders calls across threads gets a diagram of both orders | both arms read the diff; the skill drew the order that raced beside the order that does not, in one sequence, and shipped through one gate call |
| [0005](0005.md) | A change inside one function gets no diagram; an update after a new commit rewrites the body and keeps what a reviewer added | neither arm drew one; after a follow-up commit, the skill rewrote every stale figure and kept the reviewer's tick, `Closes #1`, and screenshot; bare kept them by editing the figures in place |
| [0006](0006.md) | An update with no new commit and no named change leaves the body alone and says why | skill only: shipped nothing, listed what the body already covers, and named what would give it a reason to change |

## Not covered

The README describes behavior no recorded run exercises yet:

- A `Verified:` section: no run had a check that ran, in the session or reported by the user, so every Testing list is reviewer items only.
- A repo PR template, one or several.
- A `[conflict]` abort, a `[stale]` base, or `[deleted]` files with an agent; `scripts/test-git-create-pr.sh` covers the report lines and the gate without one.
- The gate stopping an agent: every current run passed the lint on its first ship. The gate's failure paths (a failed lint, a warning, a pre-push hook, `gh`) are covered only by `scripts/test-git-create-pr.sh`, and History has the last agent run a warning stopped.
- An open PR whose base differs from the one asked for.
- A line another login added to a PR body: every edit on the fixture is the user's own login, so the history check has run only against the test suite's stub.
- An update where the user's own browser edit holds a note a person wrote, to see whether the agent carries it over.
- Whether GitHub renders the diagrams in 0003 and 0004; no run checked. The lint checks their shape, not that they render.
- `--accept-warnings`, for a warning that misreads its line.

## Method

| Item | Skill arms; bare arms of 0001–0002 | Bare arms of 0003–0005 |
|---|---|---|
| Date | 2026-11-12 | 2026-11-12, an earlier batch |
| Model, every arm | `claude-sonnet-5-5` | `claude-sonnet-5-5` |
| Harness | Claude Code 2.1.322 | Claude Code 2.1.322 |
| Skill under test | this folder's parent: the ship gate, the Summary that leads with the problem, the diagram shape checks, the no-change rule for updates, and keep lines read from the body's history | none |
| Skill hash | `6ba9a586bd8d` | n/a, bare arms load no skill |
| User's global `CLAUDE.md` | moved aside for the runs and restored after | moved aside for the runs and restored after |

A bare arm loads no skill, so a skill change leaves its run a valid comparison; the bare arms of 0003 to 0005 come from the batch History describes, and 0005's bare update ran in the current batch. The skill hash covers what the agent reads at run time, `SKILL.md`, `scripts/`, `examples/`, and `references/`. `bash scripts/check-evidence.sh` from the repo root says whether the skill has changed since; `--hash <skill-dir>` prints the value to record for a new batch.

Every arm ran `claude -p` with `--setting-sources project`, `--permission-mode acceptEdits`, and `--allowedTools` limited to git, gh, bash, mktemp, read-only shell commands, Read, Glob, Grep, Edit. 0005's bare update also had `--add-dir /tmp`: its first try was blocked writing a body file there, a block the skill arm, writing through `mktemp`, did not meet (see 0005). The skill under test was copied into a scratch plugin and loaded with `--plugin-dir` as plugin `eval`, so it is the repo copy rather than an installed one.

| Prompt | Value |
|---|---|
| Bare | `Open a pull request for this branch against <base>.` |
| Skill | `/eval:git-create-pr <base>` |
| Bare update (0005) | `Update the description of the open pull request for this branch.` |
| Skill update (0005, 0006) | `/eval:git-create-pr <base>` |

**Visible to both arms.** The fixture repo's own `CLAUDE.md` and `AGENTS.md`, the docs they link, and Claude Code's standing reminder to end PR descriptions with a robot-emoji "Generated with" line. The repo's `docs/conventions/git.md` gives a PR skeleton with `## Scope` and `## Changes Made`; every bare arm followed it, and the skill used its own shape (see the README's Stances). A bare arm asked before each batch to list its skills and any PR instruction it could see named only built-in skills, the harness reminder, and the repo's `AGENTS.md`.

**Hidden from both arms.** User-level skills and hooks.

**Input state.** A case is a real change set from a real project: the commits of a merged pull request, on a branch of their own, against a base branch pinned at the change set's original branch point. Each arm gets a clone of its own on a branch of its own at the same commits, so the merge-base diff is identical. The remote is a private throwaway repository holding the base branches and the arms' branches; each arm pushes its own branch and opens its own PR. The repo has no PR template, and its history titles commits conventionally. The current batch ran its arms one at a time, so no two pushes raced.

**What is compared.** Whether the agent read the diff or only the commit messages, the title and its style, the body's sections, whether the Summary leads with the problem, whether Testing items name real commands, paths, or behaviors from the diff, whether an Impact section appears only when the change carries a consequence, whether a diagram appears and what it draws, what an update keeps and whether it changes the body at all, any provenance footer, whether the push was plain and the base correct, and the turn count and cost the harness reported. The body of the original pull request is not an arm: it was written with an earlier version of the skill and an unrecorded model.

**Rerunning.** Any merged change set works as a new case: fetch its head (for a squash-merged PR, `pull/<n>/head`), create a base branch at its branch point on a throwaway remote, check out the commits on a fresh branch, and run each arm from inside it with the flags above. Transcripts come from `--output-format stream-json --verbose`; they are not committed here because each is 30 to 150 KB of JSON, but every number in a case file was read from one.

## History

Earlier runs on earlier states of the skill, and the rule each one changed. None is recorded as a case, so read these as notes, not evidence.

| Batch | Date | Skill hash | What ran |
|---|---|---|---|
| 1 | 2026-10-08 | `44bbdcdad6de` (commit `8f85865`) | both arms of 0001 and 0002, harness 2.1.293, the user's global `CLAUDE.md` probably visible |
| 2 | 2026-11-12 | `103bde77fffd` | the skill arms of 0003 to 0005, before the ship gate |

- **Bare read only the commit messages, in batch 1.** Neither bare arm of 0001 or 0002 opened the diff, and their bodies restated the commit messages. In the current batch, 0001's bare arm read the first 200 lines of the diff and wrote per-file changes much like the skill's, so the arms there now differ in how the body reads rather than in what each read (see 0001); 0002's still read only the messages. Batch 1 ran with the user's global `CLAUDE.md` probably visible, which `--setting-sources project` does not hide, so its bare arms and these differ in more than chance.
- **Testing became evidence and work.** Batch 1's skill bodies listed Testing as unticked boxes with no labels. The split into `Verified:` and `For the reviewer:`, with a ticked box failing the lint, came after it.
- **The Summary leads with the problem.** In batch 2 every skill Summary opened on the change: 0004's left the problem to "can no longer hang", and 0005's put the old behavior and the fail-open fact in one sentence joined by "and". The template then read "what this PR accomplishes and why", and the one-tense rule gave no way to state the old behavior. Both changed: the Summary states the problem first, and behavior before the change takes the past tense in a sentence of its own.
- **A race needs both orders.** Batch 2's 0004 drew only the order after the fix, while the bug was the stop that landed before the loop ran. The Diagram block now says to draw both flows when the change is the difference, with a race as the case.
- **An update needs a reason.** Batch 2's 0005 update rewrote a body that still matched its branch, changing only wording; bare saw the body was current and left it alone. Updates now change the body only for a new commit or a change the user names (0006).
- **One gate ships the PR.** In batch 2 the agent wrote the body, ran `--lint`, then `git push`, then `gh pr create` or `gh pr edit`, carrying the body path, the title, the PR number, and the saved body between the calls; a forgotten `--existing` would have passed a body that dropped `Closes #12`. `--ship` now does all of it after one lint.
- **The lint names one hit per kind.** In batch 2's 0003 the lint warned on a bullet opening with "Disconnecting"; the skill swapped in "Unplugging", another -ing word, and a second flagged bullet stayed hidden until the first was fixed. The lint still reports only the first hit of each kind.
- **Pushes race on a shared remote.** Batch 2 pushed six arms at once: one push was rejected and retried, and another printed pack errors. Batches since run one arm at a time.
