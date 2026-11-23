# Evidence

Recorded runs that back the claims in the skill's README. The case is a fixture repo that `fixtures.sh` builds, audited by an agent running this skill. It runs the skill arm alone: what is under test is how the agent uses the audit in Step 1 and that it stops for confirmation before changing anything, which a bare agent has no audit or workflow to compare against. These are runs to read and judge, not tests with a pass or fail; the audit's own output is tested by the repo's `scripts/test-doc-driven-dev.sh`. Everything above History describes the current runs.

| Case | Claim | Result |
|---|---|---|
| [0001](0001.md) | Step 1 takes its facts from one audit call, judges every doc the audit lists, and changes nothing before the user confirms the plan | all three runs: one unpiped audit call; every doc categorized, the oversized root `ARCHITECTURE.md` as relocate and split by its three sections; the missing structure named from the audit; the rules' reasons asked for, not supplied; `git status` clean |

## Not covered

The README describes behavior no recorded run exercises yet:

- Steps 2 to 6. Every run is headless and ends at Step 1's confirmation, so the reorganization, the category walk, the root index and its axes, the migration check, and the closing audit are unrecorded.
- A project with no `docs/` at all, or outside git: covered by the repo's tests, not by a run.
- A digest cut at its budget: the case's audit is 1.4 KB.

## Method

| Item | Batch 10 |
|---|---|
| Date | 2026-11-22 |
| Model, every arm | `claude-opus-5-5` |
| Harness | Claude Code 2.1.322 |
| Skill under test | this folder's parent, as committed with this evidence |
| Skill hash | `e64ba8f3024e` |
| Runs | three, each in parallel with the brief and debrief arms of its run |

The skill hash covers what the agent reads at run time (`SKILL.md`, `scripts/`); `bash scripts/check-evidence.sh` from the repo root says whether the skill has changed since, and `--hash <skill-dir>` prints the value to record for a new batch.

Every arm ran `claude -p` from inside its fixture repo with `--setting-sources project`, `--permission-mode acceptEdits`, and `--allowedTools` set to `Bash(git:*)`, `Bash(bash:*)`, `Bash(printf:*)`, `Bash(cat:*)`, `Bash(head:*)`, `Bash(tail:*)`, `Bash(ls:*)`, `Bash(wc:*)`, `Bash(grep:*)`, `Bash(echo:*)`, `Bash(sed:*)`, `Bash(find:*)`, `Bash(mkdir:*)`, `Bash(mv:*)`, Read, Glob, Grep, Edit, Write. The three doc-driven-dev skills were copied into a scratch plugin and loaded with `--plugin-dir` as plugin `eval`, so the skill is the repo copy rather than an installed one. Git ran with `GIT_CONFIG_GLOBAL=/dev/null` and a neutral author.

**Visible to the arm.** The fixture repo's `CLAUDE.md`.

**Hidden from the arm.** User-level `CLAUDE.md`, user skills, user hooks. Before batch 1, an arm with the same flags, asked to list its skills and any instruction file it could see, named only the three `eval:` skills and built-in ones, and no instruction file.

**Input state.** `bash fixtures.sh 0001 <dir>` builds the repo from nothing.

**What is compared.** The audit calls and whether any was piped; which docs the summary categorizes and how; whether the summary names what the audit found missing; and whether anything changed before the confirmation (the fixture's `git status`). Transcripts came from `--output-format stream-json --verbose`; they are not committed, and every number here was read from one.

## History

Before this version the skill had no script: Step 1 asked the agent to `Glob` the docs and count sizes, indexes, and orphans itself, and the last 30 days of the maintainer's transcripts hold no `/setup-docs` run to show how that went. Batches 1 and 2 ran this case on earlier audit states (`8d4434b987c3`, both batches) with the same result as the recorded run; the audit changed after them only in naming the sections a cut digest leaves out. Batches 3 and 4 (`41113290de66`) matched it too. After them the docs contract, shared with brief and debrief, gained a rule on where a **Why:**'s reason comes from, because a debrief run wrote a cause no file stated; in batch 6 this case asked for the reasons behind the rules it found instead. Batch 7 ran it twice more on `39ada343179e`, beside a copy of the three skills reworded to Simplified Technical English; all four runs, two of each, matched the recorded result. After it, Step 1 says to write the script's full path in every call, because batch 7's runs met harness refusals for a path held in a shell variable; batch 8 (`e64ba8f3024e`) ran this case twice on Opus with the recorded result. Batch 10 ran it three more times on the same state, with the recorded result in each.
