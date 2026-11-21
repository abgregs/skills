# Evidence

Recorded runs that back the claims in the skill's README. Each case is a fixture repo that `fixtures.sh` builds, with committed work that left the docs stale, debriefed by an agent running this skill. Every case runs the skill arm alone: what is under test is how the agent picks the base, judges the sweep's findings, and ends the debrief, which a bare agent has no sweep to compare against. These are runs to read and judge, not tests with a pass or fail; the sweep's own behavior, each exit code and refusal included, is tested by the repo's `scripts/test-doc-driven-dev.sh`. Everything above History describes the current runs.

| Case | Claim | Result |
|---|---|---|
| [0001](0001.md) | A branch in a fresh worktree is compared from its branch point, not its last five commits; the stale convention is fixed with a **Why:**, every finding is judged before the mark, and the mark lands where every worktree sees it | both runs: `--scope` picked the merge-base; `api-endpoints.md` rewritten from `X-Session` to the bearer header with a **Why:**; `--verdicts` exit 0, then commit and `--mark` into the common git dir; nothing under `.claude/`; a planning index added from the standing faults |
| [0002](0002.md) | When the user names the range, the agent passes it as `--base`, so a finding from before the range stays out | both runs: `--scope --base v1.2`; the sweep found only the post-tag `archived` term and one referrer, not v1.2's `workspace`; both fixed, the re-sweep clean, then commit and mark |

## Not covered

The README describes behavior no recorded run exercises yet:

- A `--mark` refused for unjudged findings, and the `--accept-unjudged` override. Since the guard went in (batch 3), every run judged its findings before marking, so no run met the refusal; the refusal and the override are covered by the repo's tests.
- A `--verdicts` exit 2 that the agent then clears: no run sent an incomplete set.
- The axis audit finding a bad composition, and its AskUserQuestion: the fixtures' axes hold no conflict, and the arms run headless with every recommended option approved in the prompt.
- Step 3's confirmation: the prompt approves every recommended update, so no run shows the question or a user's edit to the proposal.
- A cut digest, `F` freshness findings, and `S` findings in a touched doc. The cases' digests were 0.5 to 1.9 KB, and no fixture has a stamp or a fault in a changed doc; each is covered by the repo's tests.
- A legacy `.claude/last-doc-sweep` mark: read only by the tests.

## Method

| Item | Batch 3 | Batch 4 |
|---|---|---|
| Date | 2026-11-21 | 2026-11-21 |
| Model, every arm | `claude-sonnet-5-5` | `claude-sonnet-5-5` |
| Harness | Claude Code 2.1.322 | Claude Code 2.1.322 |
| Skill under test | this folder's parent, as committed with this evidence | the same |
| Skill hash | `70ffd593abc7` | `70ffd593abc7` |
| Runs | one per case, in parallel with the brief and setup-docs arms of the batch | the same |

The skill hash covers what the agent reads at run time (`SKILL.md`, `scripts/`, `examples/`); `bash scripts/check-evidence.sh` from the repo root says whether the skill has changed since, and `--hash <skill-dir>` prints the value to record for a new batch.

Every arm ran `claude -p` from inside its fixture repo with `--setting-sources project`, `--permission-mode acceptEdits`, and `--allowedTools` set to `Bash(git:*)`, `Bash(bash:*)`, `Bash(printf:*)`, `Bash(cat:*)`, `Bash(head:*)`, `Bash(tail:*)`, `Bash(ls:*)`, `Bash(wc:*)`, `Bash(grep:*)`, `Bash(echo:*)`, `Bash(sed:*)`, `Bash(find:*)`, `Bash(mkdir:*)`, `Bash(mv:*)`, Read, Glob, Grep, Edit, Write. The three doc-driven-dev skills were copied into a scratch plugin and loaded with `--plugin-dir` as plugin `eval`, so the skill is the repo copy rather than an installed one. Git ran with `GIT_CONFIG_GLOBAL=/dev/null` and a neutral author, so no user git config reached a run.

**Visible to the arm.** The fixture repo's `CLAUDE.md`, and the prompt's standing approval: "The user is away for this run: treat every doc update you recommend as approved, and take your recommended option wherever you would ask a question."

**Hidden from the arm.** User-level `CLAUDE.md`, user skills, user hooks. Before batch 1, an arm with the same flags, asked to list its skills and any instruction file it could see, named only the three `eval:` skills and built-in ones, and no instruction file; in this harness version `--setting-sources project` keeps the user's `~/.claude/CLAUDE.md` out, so it was not moved.

**Harness refusals.** With these flags the harness refuses a Bash command holding a shell variable it cannot check (`S=<path>; bash $S`, `echo exit $?`). Each run met one to three such refusals, wrote the path out in full, and went on; the refusals are the harness's, not the skill's, and the verdict results now name their exit code so that no `$?` is needed.

**Input state.** `bash fixtures.sh <case> <dir>` builds each repo from nothing; the case file names its prompt and where the arm runs.

**What is compared.** The base `--scope` printed and how it was chosen; each sweep's findings by ID; whether any detector call was piped; each `--verdicts` and `--mark` result; the docs the commit changed; whether `docs/` still uses the retired terms outside **Why:** lines; and where the mark landed. Transcripts came from `--output-format stream-json --verbose`; they are not committed, and every number here was read from one.

## History

**Before this version.** The last 30 days of the maintainer's Claude Code transcripts held 15 `/debrief` runs across four projects, on the sweep that kept its mark in `.claude/last-doc-sweep`. Step 1 diffed the working tree, but in nearly every run the work was already committed and the agent took a commit range from the arguments, such as `origin/main...HEAD`. The sweep took its base from the mark, which each worktree kept apart: five runs in fresh worktrees fell back to `HEAD~5`, so the PR #92 debrief swept 5 of its 10 commits, and one run copied a sibling worktree's mark by hand. 31 of the 42 sweep calls were piped through `head` or `sed`, and the 40-term cap was hit in 4 runs, where it kept the candidates first in the alphabet. Those runs drove `--scope`, the shared mark, the merge-base fallback, the ranked cap, and the digest.

Batches 1 and 2 ran on earlier states of this version; neither is recorded as a case. A first start of batch 1 was stopped before any arm finished, because git ran with no author and a commit would have failed for that alone.

| Batch | Skill hash | What it changed |
|---|---|---|
| 1 | `c9d8f247c201` | `--verdicts` took a file, and 0001 tried `/tmp/verdicts.txt` (refused as outside the working directory) before writing `docs/.verdicts.tmp` into the docs it was checking. `--verdicts -` now reads stdin, and the script keeps each debrief's verdicts in the git directory. |
| 2 | `99013e5165c8` | 0002 tried `--verdicts` three times, each refused by the harness for an `echo exit $?`, then committed and ran `--mark` with its findings unjudged; 0001 judged them only in the same command as its mark. `--mark` now refuses while a finding of the last sweep has no verdict, `--accept-unjudged` is the user's override, and every verdict result names its exit code. Batch 2's dry run of the 0002 fixture also showed `workspace` counted twice, as a backticked phrase and as a word; candidates are now one per term. |
