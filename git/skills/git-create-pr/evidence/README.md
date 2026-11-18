# Evidence

Recorded runs that back the claims in the skill's README. Each case is one branch of real commits opened as a pull request two ways, by a bare agent and by the same agent running this skill, with the resulting title and body quoted as GitHub stored them; 0006 runs the skill alone, on a PR an earlier run opened. Cases are numbered and stand on their own; nothing in them depends on where the input came from. These are comparisons to read and judge, not tests with a pass or fail; the method below is enough to rerun any of them. Everything above History describes runs of the skill as it now stands; History summarizes the earlier ones that shaped the rules.

| Case | Claim | Result |
|---|---|---|
| [0001](0001.md) | The body is written from the diff for a reviewer: the problem first, per-file changes, checkable testing items, no provenance | both arms read the diff and wrote per-file changes; the skill's Summary states the bug and what it cost, then the fix, where bare's opens on "no longer swallows" and leaves the cause to Impact; the skill ran the test suite and cited its result under `Verified:`; only bare ended with a tool footer |
| [0002](0002.md) | Impact appears only when there is a consequence to weigh, and a change a person sees gets its screenshot spot named | bare read only the commit messages; the skill read the diff, left Impact out of a figures-only fix, and named the picker as the one screenshot spot |
| [0003](0003.md) | A change that moves structure ends Summary with one Mermaid diagram | bare drew nothing; the skill led with the call-mode problem and drew how the capture device is chosen as one flowchart |
| [0004](0004.md) | A change that reorders calls across threads gets a diagram of both orders | both arms read the diff; the skill drew the order that raced beside the order that does not, as one sequence, and shipped through one gate call |
| [0005](0005.md) | A change inside one function gets no diagram; an update after a new commit rewrites the body and keeps what a reviewer added | neither arm drew one; after a follow-up commit, which the preflight counted since the body's last save, the skill rewrote every stale figure and kept the reviewer's tick, `Closes #1`, and screenshot; bare kept them by editing the figures in place |
| [0006](0006.md) | An update with no new commit and no named change leaves the body alone and says why | skill only: the preflight counted no commit since the body's last save; the skill shipped nothing in two turns and said what it checked and what would give the body a reason to change |

## Not covered

The README describes behavior no recorded run exercises yet:

- A `Verified:` bullet from a check the user reported, such as a CI link or the screenshots they send; 0001's holds only a check run in the session. The lint's failure for a `Verified:` that holds no check is covered by `scripts/test-git-create-pr.sh`; no current run wrote one to fail.
- A repo PR template, one or several, with an agent. `scripts/test-git-create-pr.sh` covers the lint and the report for both, and generated files left out of the diff.
- A `[conflict]` abort, a `[stale]` base, or `[deleted]` files with an agent; `scripts/test-git-create-pr.sh` covers the report lines and the gate without one.
- The gate stopping an agent: every current run passed the lint on its first ship. The gate's stops, each with its own exit (a failed lint, a warning, a preflight abort, a pre-push hook, a refused push or `gh`), and the hand-back on a repeated stop are covered only by `scripts/test-git-create-pr.sh`, and History has the probe runs a lint stopped.
- An edit after a lint stop on the current wording. Step 3 now reads the body back, which is what lets `Edit` change the file later, and 3 of the 6 current runs that shipped read it; with no stop, none needed the edit. History has the probe run whose first edit failed without that read.
- An open PR whose base differs from the one asked for.
- A line another login added to a PR body: every edit on the fixture is the user's own login, so the history check has run only against the test suite's stub.
- An update where the user's own browser edit holds a note a person wrote, to see whether the agent carries it over.
- Whether GitHub renders the diagrams in 0003 and 0004; no run checked. The lint checks their shape, not that they render.
- `--accept-warnings`, for a warning that misreads its line.

## Method

| Item | Skill arms | Bare arms |
|---|---|---|
| Date | 2026-11-18 | 2026-11-12: 0001, 0002, and 0005's update in batch 3, 0003 to 0005's opening in batch 2 |
| Model, every arm | `claude-sonnet-5-5` | `claude-sonnet-5-5` |
| Harness | Claude Code 2.1.322 | Claude Code 2.1.322 |
| Skill under test | this folder's parent: the ship gate with one exit per stop and the hand-back, every lint hit in one pass, a lint failure for a `Verified:` that holds no check, a lint warning on an Impact line that says there is nothing to weigh, the title in its own file, the body's last-saved count for updates, the Summary that leads with the problem, the diagram decided in step 2 and named in the reply, the body read back before an edit, a template that shows `Verified:` only when a check ran and reviewer boxes that open on a verb, the diagram shape checks, and keep lines read from the body's history | none |
| Skill hash | `2afe335e61e8` | n/a, bare arms load no skill |
| User's global `CLAUDE.md` | moved aside for the runs and restored after | moved aside for the runs and restored after |

A bare arm loads no skill, so a skill change leaves its run a valid comparison; the bare arms come from batches 2 and 3, which History describes. The skill arms of 0001 to 0005 opened fixture PRs #60 to #64; 0006 ran on PR #8, as the batches before it did. The skill hash covers what the agent reads at run time, `SKILL.md`, `scripts/`, `examples/`, and `references/`. `bash scripts/check-evidence.sh` from the repo root says whether the skill has changed since; `--hash <skill-dir>` prints the value to record for a new batch.

Every arm ran `claude -p` with `--setting-sources project`, `--permission-mode acceptEdits`, and `--allowedTools` limited to git, gh, bash, mktemp, read-only shell commands, Read, Glob, Grep, Edit. 0005's bare update also had `--add-dir /tmp`: its first try was blocked writing a body file there, a block the skill arm, writing through `mktemp`, did not meet (see 0005). 0001's skill arm ran `swift test`, which the list does not name, and the run logged no permission denial; the probes' runs did the same, so the list is not the only thing deciding what an arm may run. The skill under test was copied into a scratch plugin and loaded with `--plugin-dir` as plugin `eval`, so it is the repo copy rather than an installed one.

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
| 3 | 2026-11-12 | `6ba9a586bd8d` | every skill arm, after the ship gate; the bare arms of 0001, 0002, and 0005's update |
| 4 | 2026-11-16 | `ffadc3edb816` | every skill arm, after every lint hit in one pass, one exit per ship stop, the title file, and the body's last-saved count |
| 5 | 2026-11-16 | `036a0e829bc6` | every skill arm, after the lint failure for a `Verified:` that holds no check and the no-change reply that states its count |
| probe A | 2026-11-18 | `036a0e829bc6` | the skill arms of 0001 to 0005 three times each, fixture PRs #30 to #44, and 0006 three times: 18 runs, $1.93 |
| probe B | 2026-11-18 | `4287831af4bb` | the same 18 runs, PRs #45 to #59, after the Impact block named the shape of an Impact with nothing to weigh and the lint began warning on it, step 2 began deciding the diagram and the reply naming it, and Testing said that reading the diff is not a check: $1.98 |

- **Bare read only the commit messages, in batch 1.** Neither bare arm of 0001 or 0002 opened the diff, and their bodies restated the commit messages. In the current batch, 0001's bare arm read the first 200 lines of the diff and wrote per-file changes much like the skill's, so the arms there now differ in how the body reads rather than in what each read (see 0001); 0002's still read only the messages. Batch 1 ran with the user's global `CLAUDE.md` probably visible, which `--setting-sources project` does not hide, so its bare arms and these differ in more than chance.
- **Testing became evidence and work.** Batch 1's skill bodies listed Testing as unticked boxes with no labels. The split into `Verified:` and `For the reviewer:`, with a ticked box failing the lint, came after it.
- **The Summary leads with the problem.** In batch 2 every skill Summary opened on the change: 0004's left the problem to "can no longer hang", and 0005's put the old behavior and the fail-open fact in one sentence joined by "and". The template then read "what this PR accomplishes and why", and the one-tense rule gave no way to state the old behavior. Both changed: the Summary states the problem first, and behavior before the change takes the past tense in a sentence of its own.
- **A race needs both orders.** Batch 2's 0004 drew only the order after the fix, while the bug was the stop that landed before the loop ran. The Diagram block now says to draw both flows when the change is the difference, with a race as the case.
- **An update needs a reason.** Batch 2's 0005 update rewrote a body that still matched its branch, changing only wording; bare saw the body was current and left it alone. Updates now change the body only for a new commit or a change the user names (0006).
- **One gate ships the PR.** In batch 2 the agent wrote the body, ran `--lint`, then `git push`, then `gh pr create` or `gh pr edit`, carrying the body path, the title, the PR number, and the saved body between the calls; a forgotten `--existing` would have passed a body that dropped `Closes #12`. `--ship` now does all of it after one lint.
- **The lint names one hit per kind.** In batch 2's 0003 the lint warned on a bullet opening with "Disconnecting"; the skill swapped in "Unplugging", another -ing word, and a second flagged bullet stayed hidden until the first was fixed. The lint now reports every hit of each kind in one pass, in the block it shares with `git-commit`.
- **An update decides from a count, and says only what it checked.** Batch 3's 0006 read the body against the diff to decide that nothing had changed: 5 turns and $0.109. The preflight then began printing the commits since the body was last saved, and batch 4's 0006 decided from that line alone in 2 turns, but its reply said the body "still describes" the commit, which it had not read; it followed `SKILL.md`'s example reply, which said the same. The example now states the count, and the replies since, batch 5's and the current one, say what they checked and that they did not read the body.
- **One run per case hides how often a judgment rule holds.** Batch 3's 0002 left Impact out of a figures-only fix; batches 4 and 5 both wrote an Impact with nothing to weigh. Batch 4's 0004 labelled a `Verified:` that held only "None run in this session.", which the lint now fails. Batch 5's 0003 drew no diagram, where batches 3 and 4 each drew one. None of those rules' wording changed across the three batches, so each case's single run showed a rule can hold, not how often it does. The probes ran every case three times on one hash to count it.
- **Counted, the judgment rules held on most runs, and wording moved two of them.** Probe A, on batch 5's skill, left Impact out of 0002 in 2 of 3 runs; the third wrote "Only user-visible strings change: the picker hints and the Homebrew caveat text." It drew 0003's diagram in 2 of 3, 0004's two orders in 2 of 3, and named the diagram decision in 4 of its 15 replies. The Impact block then named that shape ("no behavior change", "user-visible text only") and the lint began warning on it; step 2 began deciding the diagram, and the reply began naming the decision. Probe B, on that wording, left Impact out of 0002 in 3 of 3 with no warning firing, drew 0004's two orders in 3 of 3, drew 0003's diagram in 2 of 3 with the miss now stated in its reply, and named the decision in 13 of 15 replies. Both probes left 0006's body alone in 3 of 3 and wrote no footer in any of their 30 runs that shipped. In 2 of probe B's 3 runs of 0002, `Verified:` held the size measurement a planning doc in the diff records: a check someone ran before the branch, which the rule's two sources, the session and the user, do not cover; the current batch's run did not cite it. Three runs a case show direction, not a rate.
- **A stop the first draft can avoid moves into the instructions.** Each probe had one lint stop in its 15 runs that shipped. Probe A's 0004 labelled a `Verified:` that held no check; the template showed the label with a bullet under it on every run, and now opens it with "Only when a check ran". Probe B's 0003 was warned on a reviewer box opening "Unplugging a USB microphone…", where the lint's fix, to start with the code that acts, does not fit a step for a reviewer. Its `Edit` was refused, since the session had not read the body file a heredoc wrote, so it shipped the body unchanged and the gate called the stop a repeat; it then read the file, edited it, and shipped, past the hand-back a repeat asks for. The template and Testing now give a reviewer box as a verb and what to confirm, step 3 reads the body back, which also lets `Edit` change it, and step 4 ships only after the edit succeeds. The current batch read the body back in 3 of its 6 runs that shipped, where batch 5 read it in none, and none of its runs stopped.
- **Pushes race on a shared remote.** Batch 2 pushed six arms at once: one push was rejected and retried, and another printed pack errors. Batches since run one arm at a time.
