# Evidence

Recorded runs that back the claims in the skill's README. Each case is a fixture repo that `fixtures.sh` builds, with work, committed or not, that left the docs stale, debriefed by an agent running this skill. Every case runs the skill arm alone: what is under test is how the agent picks the base, judges the sweep's findings, and ends the debrief, which a bare agent has no sweep to compare against. These are runs to read and judge, not tests with a pass or fail; the sweep's own behavior, each exit code and refusal included, is tested by the repo's `scripts/test-doc-driven-dev.sh`. Everything above History describes the current runs.

| Case | Claim | Result |
|---|---|---|
| [0001](0001.md) | A branch in a fresh worktree is compared from its branch point, not its last five commits; the stale convention is fixed with a **Why:**, every finding is judged before the mark, and the fixes are committed before the mark lands where every worktree sees it | both runs: `--scope` picked the merge-base; `api-endpoints.md` rewritten from `X-Session` to the bearer header with a **Why:** reading `reason not recorded`; `--verdicts` exit 0, then commit, then `--mark` into the common git dir; nothing under `.claude/` |
| [0002](0002.md) | When the user names the range, the agent passes it as `--base`, so a finding from before the range stays out | both runs: `--scope --base v1.2`; the sweep found only the post-tag `archived` term and one referrer, not v1.2's `workspace`; both handled, then commit and mark; every **Why:** reads `reason not recorded`, no cause supplied |
| [0003](0003.md) | Uncommitted work on a branch with no commits is reviewed from HEAD, not `HEAD~5`, and the untracked file is read | both runs: base HEAD; `src/currency.js` read, and its float-drift reason quoted in the new **Why:**; doc fixes left uncommitted beside the code, the mark set at HEAD, and both said so |
| [0004](0004.md) | With no mark, no branch commits, and a clean tree, `--scope` refuses to guess and the agent stops for a range | both runs: exit 4, then a stop with no sweep, edit, or mark; a candidate range offered for the user to confirm, not taken |

## Not covered

The README describes behavior no recorded run exercises yet:

- A `--mark` refused for unjudged findings, and the `--accept-unjudged` override. Since the guard went in (batch 3), every run judged its findings before marking, so no run met the refusal; the refusal and the override are covered by the repo's tests.
- A `--verdicts` exit 2 that the agent then clears: no run sent an incomplete set.
- `--scope` exit 3, nothing changed since the base: covered by the tests, not by a run.
- Exit 4 with a user to ask. Every arm runs headless, so 0004 shows the stop, not the question or the debrief after the user's answer.
- The axis audit finding a bad composition, and its AskUserQuestion: the fixtures' axes hold no conflict.
- Step 3's confirmation: the prompt approves every recommended update, so no run shows the question or a user's edit to the proposal.
- A cut digest, `F` freshness findings, and `S` findings in a touched doc. The cases' digests were 0.5 to 1.9 KB, and no fixture has a stamp or a fault in a changed doc; each is covered by the repo's tests.
- A legacy `.claude/last-doc-sweep` mark: read only by the tests.

## Method

| Item | Batch 7 |
|---|---|
| Date | 2026-11-21 |
| Model, every arm | `claude-sonnet-5-5` |
| Harness | Claude Code 2.1.322 |
| Skill under test | this folder's parent, as committed with this evidence |
| Skill hash | `243a4a301264` |
| Runs | two per case, in parallel with the brief and setup-docs cases and with a copy of all three skills reworded to Simplified Technical English (see History) |

The skill hash covers what the agent reads at run time (`SKILL.md`, `scripts/`, `examples/`); `bash scripts/check-evidence.sh` from the repo root says whether the skill has changed since, and `--hash <skill-dir>` prints the value to record for a new batch.

Every arm ran `claude -p` from inside its fixture repo with `--setting-sources project`, `--permission-mode acceptEdits`, and `--allowedTools` set to `Bash(git:*)`, `Bash(bash:*)`, `Bash(printf:*)`, `Bash(cat:*)`, `Bash(head:*)`, `Bash(tail:*)`, `Bash(ls:*)`, `Bash(wc:*)`, `Bash(grep:*)`, `Bash(echo:*)`, `Bash(sed:*)`, `Bash(find:*)`, `Bash(mkdir:*)`, `Bash(mv:*)`, Read, Glob, Grep, Edit, Write. The three doc-driven-dev skills were copied into a scratch plugin and loaded with `--plugin-dir` as plugin `eval`, so the skill is the repo copy rather than an installed one. Git ran with `GIT_CONFIG_GLOBAL=/dev/null` and a neutral author, so no user git config reached a run.

**Visible to the arm.** The fixture repo's `CLAUDE.md`, and the prompt's standing approval: "The user is away for this run: treat every doc update you recommend as approved, and take your recommended option wherever you would ask a question."

**Hidden from the arm.** User-level `CLAUDE.md`, user skills, user hooks. Before batch 1, an arm with the same flags, asked to list its skills and any instruction file it could see, named only the three `eval:` skills and built-in ones, and no instruction file; in this harness version `--setting-sources project` keeps the user's `~/.claude/CLAUDE.md` out, so it was not moved.

**Harness refusals.** With these flags the harness refuses a Bash command holding a shell variable it cannot check (`S=<path>; bash $S`, `echo exit $?`) or a compound command with a part it cannot approve. Each run of batches 1 to 5 met one to three such refusals; in batch 7, six of the eight met one or two, wrote the command out in full, and went on; the refusals are the harness's, not the skill's, and the verdict results name their exit code so that no `$?` is needed.

**Input state.** `bash fixtures.sh <case> <dir>` builds each repo from nothing; the case file names its prompt and where the arm runs.

**What is compared.** The base `--scope` printed and how it was chosen; each sweep's findings by ID; whether any detector call was piped; each `--verdicts` and `--mark` result; the docs the commit changed; whether `docs/` still uses the retired terms outside **Why:** lines; where the mark landed; and, for uncommitted work, whether the untracked files were read. Transcripts came from `--output-format stream-json --verbose`; they are not committed, and every number here was read from one.

## History

**Before this version.** The last 30 days of the maintainer's Claude Code transcripts held 15 `/debrief` runs across four projects, on the sweep that kept its mark in `.claude/last-doc-sweep`. Step 1 diffed the working tree, but in nearly every run the work was already committed and the agent took a commit range from the arguments, such as `origin/main...HEAD`. The sweep took its base from the mark, which each worktree kept apart: five runs in fresh worktrees fell back to `HEAD~5`, so the PR #92 debrief swept 5 of its 10 commits, and one run copied a sibling worktree's mark by hand. 31 of the 42 sweep calls were piped through `head` or `sed`, and the 40-term cap was hit in 4 runs, where it kept the candidates first in the alphabet. Those runs drove `--scope`, the shared mark, the merge-base fallback, the ranked cap, and the digest.

Batches 1 to 4 ran on earlier states of this version. A first start of batch 1 was stopped before any arm finished, because git ran with no author and a commit would have failed for that alone.

| Batch | Skill hash | What it changed |
|---|---|---|
| 1 | `c9d8f247c201` | `--verdicts` took a file, and 0001 tried `/tmp/verdicts.txt` (refused as outside the working directory) before writing `docs/.verdicts.tmp` into the docs it was checking. `--verdicts -` now reads stdin, and the script keeps each debrief's verdicts in the git directory. |
| 2 | `99013e5165c8` | 0002 tried `--verdicts` three times, each refused by the harness for an `echo exit $?`, then committed and ran `--mark` with its findings unjudged; 0001 judged them only in the same command as its mark. `--mark` now refuses while a finding of the last sweep has no verdict, `--accept-unjudged` is the user's override, and every verdict result names its exit code. Batch 2's dry run of the 0002 fixture also showed `workspace` counted twice, as a backticked phrase and as a word; candidates are now one per term. |
| 3, 4 | `70ffd593abc7` | 0001 and 0002 passed as recorded in their case files; nothing to change from the runs. A review after them found that a branch with no commits, or the default branch with no mark, still fell back to `HEAD~5`, and that `git diff <base>` leaves untracked files out. `--scope` now takes HEAD when only uncommitted changes exist, refuses a clean tree with no base (exit 4) or nothing changed (exit 3), and lists untracked files to read; 0003 and 0004 were added for it. |
| 5 | `5edc0cb8ebd7` | 0002's agent wrote a **Why:** with a cause no file states, and the skill did not say where a **Why:**'s reason must come from; the docs contract now does. 0003 left its fixes uncommitted beside the uncommitted code and did not mark; Step 6 now says to leave them there and mark anyway. 0004 took the standing approval as leave to pick a range itself. |
| 6 | `2e47c7b601cb` | Every **Why:** was sourced or read `reason not recorded`, and 0004 stopped at exit 4. 0001 left its fixes uncommitted although its code was committed, and did not mark: Step 6's new sentence on uncommitted code had made commit-then-mark read as the exception. Step 6 now states commit, then mark, as the rule, and the uncommitted case after it. |
| 7 | `243a4a301264` | The current runs, two per case. Every case passed in both. The same batch ran a copy of the three skills reworded to Simplified Technical English: one instruction per sentence, the condition before the action, no parentheticals, sentences of at most 25 words. Brief and setup-docs tied with the current wording. In debrief, all four reworded runs of 0001 and 0002 left committed-code fixes uncommitted, where all four runs here committed and marked: the rewording had split Step 6 into two equal cases, and the agents took the uncommitted one. The reworded copy was not adopted. |
