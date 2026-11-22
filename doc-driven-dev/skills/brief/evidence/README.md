# Evidence

Recorded runs that back the claims in the skill's README. Each case is a fixture repo that `fixtures.sh` builds, briefed by an agent running this skill. Every case runs the skill arm alone: what is under test is how the agent uses the scout's digest and where the workflow stops, which a bare agent has no digest or workflow to compare against. These are runs to read and judge, not tests with a pass or fail; the scout's own behavior is tested by the repo's `scripts/test-doc-driven-dev.sh`. Everything above History describes the current runs.

| Case | Claim | Result |
|---|---|---|
| [0001](0001.md) | On a corpus whose old scout report ran to 88 KB, the agent reads the digest in one call, reads the shortlisted docs in full, cites each rule on its line, and names a tension between two rules before it plans | one unpiped scout call of 7.8 KB; nine files read; 12 citations, each on its rule's line; the 10-minute cache against the 5-minute deletion rule named before the plan; two questions; no code written |
| [0002](0002.md) | With no `docs/`, the skill neither blocks nor sends the user to `/setup-docs` when `CLAUDE.md` holds conventions | the scout prints `CLAUDE.md` as the fallback; all three conventions cited on their lines; `/setup-docs` named only among the non-blocking gaps; two questions, then a plan, no code written |
| [0003](0003.md) | A digest cut at its budget still carries the shortlist, so the briefing matches the uncut one | the digest cut inside section 3, naming sections 4 and 5 as left out; the same `docs/` rules on the same lines as 0001; the full report opened, with no change to the briefing |

## Not covered

The README describes behavior no recorded run exercises yet:

- A real corpus. The cases are fixtures; the transcripts History describes were real projects, on the earlier scout.
- Step 4's doc edits: no case has a task that changes a convention, so no run proposes or makes a doc update before planning.
- The user's answers. Every arm runs headless, so each ends on its questions or its plan; what the skill does once the user answers is unrecorded.
- Plan mode: headless runs have none, so whether the skill enters it where the harness offers one is unrecorded.
- A task whose terms are all shorter than four letters, and a scout run outside a git repo. The scout's output for both is covered by the repo's tests, not by a run.

## Method

| Item | Batch 6 |
|---|---|
| Date | 2026-11-21 |
| Model, every arm | `claude-sonnet-5-5` |
| Harness | Claude Code 2.1.322 |
| Skill under test | this folder's parent, as committed with this evidence |
| Skill hash | `7e3a0b2c7088` |
| Runs | one per case, all three in parallel with the debrief and setup-docs arms of the same batch |

The skill hash covers what the agent reads at run time (`SKILL.md`, `scripts/`); `bash scripts/check-evidence.sh` from the repo root says whether the skill has changed since, and `--hash <skill-dir>` prints the value to record for a new batch.

Every arm ran `claude -p` from inside its fixture repo with `--setting-sources project`, `--permission-mode acceptEdits`, and `--allowedTools` set to `Bash(git:*)`, `Bash(bash:*)`, `Bash(printf:*)`, `Bash(cat:*)`, `Bash(head:*)`, `Bash(tail:*)`, `Bash(ls:*)`, `Bash(wc:*)`, `Bash(grep:*)`, `Bash(echo:*)`, `Bash(sed:*)`, `Bash(find:*)`, `Bash(mkdir:*)`, `Bash(mv:*)`, Read, Glob, Grep, Edit, Write. `head`, `sed`, and `grep` are allowed so that piping the digest stays possible and visible. The three doc-driven-dev skills were copied into a scratch plugin and loaded with `--plugin-dir` as plugin `eval`, so the skill is the repo copy rather than an installed one. Git ran with `GIT_CONFIG_GLOBAL=/dev/null` and a neutral author, so no user git config reached a run.

**Visible to the arm.** The fixture repo's `CLAUDE.md`.

**Hidden from the arm.** User-level `CLAUDE.md`, user skills, user hooks. Before batch 1, an arm with the same flags, asked to list its skills and any instruction file it could see, named only the three `eval:` skills and built-in ones, and no instruction file; in this harness version `--setting-sources project` keeps the user's `~/.claude/CLAUDE.md` out, so it was not moved.

**Input state.** `bash fixtures.sh <case> <dir>` builds each repo from nothing; the case file names its prompt. Case 0003 is 0001's repo with `DOC_SCOUT_BUDGET=2500` in the arm's environment, which stands in for a corpus large enough to fill the default 20 KB budget.

**What is compared.** The scout calls and whether any was piped through `head`, `sed`, or `grep`; the digest's size and whether it was cut; the docs read and how; each `file:line` citation against the line it names; whether the arm asked before planning; and whether it wrote code (the fixture's `git status` after the run). Transcripts came from `--output-format stream-json --verbose`; they are not committed, and every number here was read from one.

## History

**Before this version.** The last 30 days of the maintainer's Claude Code transcripts held 20 `/brief` runs across five projects, on the scout that printed its inventory and every `_index.md` before the shortlist. The scout ran in all 20. Of its 29 calls, 7 returned 30 to 55 KB, more than the harness shows, so the agent saw a 2 KB preview holding only `== 1. INVENTORY ==`; 20 were piped through `head` or `sed`, cutting off the shortlist at the end or skipping the index summaries. Plan mode, which the skill named as its ending, was entered in 9 of the 20. Those runs drove the digest: findings first, a budget, the full report in a file.

Batches 1 to 4 ran on earlier states of this version; none is recorded as a case.

| Batch | Skill hash | What it changed |
|---|---|---|
| 1 | `723a8bd7bd65` | 0001 cited two `api-endpoints.md` rules one line off: the arm had read that doc with `cat`, which numbers nothing. Step 2 now takes line numbers from `Read` or `grep -n`; no citation has been off since. |
| 2 | `6f6fd1ff3a92` | 0003, new in this batch, never opened the full report after the cut. The cut line then named only the report's path; it now names the section it stopped in and the sections it left out. |
| 3 | `a9e32cbbcc63` | 0003 again left the report closed, and again matched 0001's rules and lines. Step 1 had told the agent to read the left-out sections before judging the shortlist; followed in neither run, with no cost to either, it now says to open the report when the shortlist misses a doc the task needs. |
| 4 | `ddc58bd08254` | All three cases as recorded in batch 6, except that 0003 left the report closed. Nothing to change from the runs. After it, the docs contract, shared with debrief, gained a rule on where a **Why:**'s reason comes from, because a debrief run wrote a cause no file stated; batch 6 reran these cases on that state. |
| 7 | `7e3a0b2c7088` | No change: the recorded state, run twice per case beside a copy of the three skills reworded to Simplified Technical English. All six runs matched the recorded results. The reworded copy tied, with one citation a line off in a run that read `CLAUDE.md` with `cat`; it was not adopted, for debrief's result (see debrief's evidence History). |
