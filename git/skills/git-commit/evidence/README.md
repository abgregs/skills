# Evidence

Recorded runs that back the claims in the skill's README. Each case is one dirty working tree committed by the agent running this skill, and usually by a bare agent too, with the commits quoted as `git log` prints them, newest first. A case that tests only the skill's own behavior (0003, 0005) runs the skill arm alone and says so. Cases are numbered and stand on their own; nothing in them depends on where the input came from. These are comparisons to read and judge, not tests with a pass or fail; the method below is enough to rerun any of them. Everything above History describes the current runs; History summarizes the earlier ones that shaped the rules.

| Case | Claim | Result |
|---|---|---|
| [0001](0001.md) | A single-intent tree stays one commit with its docs; the body is bullets led by `Why:` when the change has a cause from outside the code, never provenance | both arms make one commit; three of four skill runs lead with a `Why:` naming the trigger, bare names none, and no skill run has a trailer |
| [0002](0002.md) | One intent across code, docs, and packaging stays one commit, and `Why:` carries the measured figure | both arms make one commit of nine files; the skill's `Why:` gives the listed and the measured size |
| [0003](0003.md) | A repo's own subject format outranks the skill's `type(scope)` stance | skill writes `WID-5: …` with the README in the same commit, its lint skips the format check, the repo's hook passes first try |
| [0004](0004.md) | A branch whose parts share files separates by type and outcome, and changes that share a source file commit together | both arms make one commit of fourteen files; the skill finds two fixes and says it joined them because one file holds code for both; four of five skill runs join them, and one splits them the other way the rules allow, each commit standing |
| [0005](0005.md) | Across repeated runs, `Why:` appears when a change has an outside cause, and grouping follows the skill's rules for binding, separating, and close calls | skill arm only, nineteen fixtures three times each: `Why:` 38/39 and grouping 51/51 on the current skill; the close call stays one commit at 20 lines and splits in three at 1,048 |
| [0006](0006.md) | Changes that each stand alone split, and one purpose across several files stays one commit when one sitting can review it | the skill makes three commits, keeping 148 lines of gap tests as one; bare makes two |

## Not covered

The README describes behavior no recorded run exercises yet:

- Single mode: every case starts with nothing staged.
- A `LINT FAIL` and its rewrite, a `commit-msg` hook that rejects the first message, and a pre-commit hook failure. The gate stops on record are `LINT WARN`s, in 0004's runs. The gate's side of all three, each stop's exit code and label, is covered by the repo's `scripts/test-git-commit.sh`; what no run shows is the agent's response.
- Repo-enforced formats other than a `commit-msg` hook set through `core.hooksPath`: commitlint, gitlint, lefthook, pre-commit, `commit.template`; and a repo whose own subjects use emoji. The lint's handling of commitlint and of the repo's history is covered by `scripts/test-git-commit.sh`, not by a run.
- A split that carries one ticket id into each of its commits.
- Untracked files beside the change, and a summary naming an untracked file a commit's code needs: no case tree has any.
- A shared source file that joins a fix and a feature, so the type order decides; 0004 joins two fixes.
- A test or doc file that covers two commits and goes in the later code commit; the probe's shared changelog (H6, H7) is the only such file on record.
- Amend mode, and `--accept-warnings` for a warning that misreads its line.

## Method

| Item | Skill arms | Bare arms |
|---|---|---|
| Date | 2026-11-15 | 2026-11-02, the batch History describes |
| Model, every arm | `claude-sonnet-5-5` | `claude-sonnet-5-5` |
| Harness | Claude Code 2.1.322 | Claude Code 2.1.299 |
| Skill under test | this folder's parent, as committed with this evidence | none |
| Skill hash | `18f737e1d4e5` | n/a, bare arms load no skill |
| Run order | case arms one at a time, alongside the 0005 probe, which slows their wall times. The 0006 arm and the three extra 0001 runs failed to sign in on their first two starts, did nothing, and ran again one at a time at the end. 0004's four extra runs and six extra P2 runs went in parallel on the same skill, just before the batch | in parallel, alongside that batch's probe |

A bare arm loads no skill, so a skill change leaves its run a valid comparison. The skill hash covers what the agent reads at run time (`SKILL.md`, `scripts/`, `examples/`, `references/`); `bash scripts/check-evidence.sh` from the repo root says whether the skill has changed since, and `--hash <skill-dir>` prints the value to record for a new batch.

Every arm ran `claude -p` with `--setting-sources project`, `--permission-mode acceptEdits`, and `--allowedTools` set to `Bash(git:*)`, `Bash(bash:*)`, `Bash(printf:*)`, `Bash(cat:*)`, `Bash(head:*)`, `Bash(tail:*)`, `Bash(ls:*)`, `Bash(wc:*)`, `Bash(grep:*)`, `Bash(echo:*)`, Read, Glob, Grep, Edit. The skill under test was copied into a scratch plugin and loaded with `--plugin-dir` as plugin `eval`, so it is the repo copy rather than an installed one. The bare prompt is `Commit the changes.`; the skill prompt is `/eval:git-commit`.

**Visible to both arms.** The fixture repo's own `CLAUDE.md` or `AGENTS.md` and the docs they link, and Claude Code's standing reminder to end commit messages with a `Co-Authored-By` line.

**Hidden from both arms.** User-level `CLAUDE.md`, user skills, user hooks. `--setting-sources project` does not hide the user's global `~/.claude/CLAUDE.md`, so it was moved aside for every batch and restored after. A bare arm asked, before each batch, to list its skills and any commit rule it could see named only built-in skills, the harness reminder, and the repo's `CLAUDE.md` and `AGENTS.md`.

**Input state.** A case is a real change set from a real project, rebuilt as the moment before any commit existed: a clone with its remote removed, checked out at the branch's head, then `git reset --mixed <branch point>`, so every change is a tracked, unstaged modification. A file the branch added is marked with `git add -N` so it counts as tracked too. Each arm gets its own clone of the identical tree, and with no remote nothing can be pushed. A case may instead be a small fixture built by hand; its file says so and lists the exact contents. Each case file describes its own input, and nothing in the method depends on which project it came from.

**What is compared.** Number of commits and which files each took, the subject, the body shape, whether a body leads with `Why:`, any provenance trailer, whether the agent staged by name or with `-A`, whether it asked a question, and the turn count and cost the harness reported. The history those changes were originally committed with is not an arm: it was made over time with an earlier version of the skill and an unrecorded model.

**Rerunning.** Any merged change set works as a new case: build its clones as above, and run each arm from inside its clone with the flags in the table. Transcripts come from `--output-format stream-json --verbose`; they are not committed here because each is 20 to 150 KB of JSON, but every number in a case file was read from one.

## History

Earlier runs on earlier states of the skill, and the rule each one changed. None is recorded as a case, so read these as notes, not evidence.

The 0005 probe ran eleven rounds, each against a different state of `SKILL.md`. Round 11 is the run 0005 records.

| Round | Date | Skill state | `Why:` correct | Grouping correct |
|---|---|---|---|---|
| 1 | 2026-10-27 | earlier `Why:` wording, earlier grouping | 14/18 (P only) | 14/18 |
| 2 | 2026-10-27 | current `Why:` wording, earlier grouping | 17/18 (P only) | 15/18 |
| 3 | 2026-10-27 | atomic grouping | 31/33 | 33/33 |
| 4 | 2026-10-27 | docs join their change | 31/33 | 33/33 |
| 5 | 2026-10-27 | type-seam grouping | 31/33 | 42/42 |
| 6 | 2026-10-30 to 11-02 | four grouping passes; a one-way dependency binds | 37/39 | 50/51 |
| 7 | 2026-10-30 to 11-02 | bind only when no order separates; close calls weighed by review; the gate commits named paths | 36/39 | 51/51 |
| 8 | 2026-10-30 to 11-02 | grouping rules after two adversarial audits | 37/39 | 51/51 |
| 9 | 2026-11-02 | bullet cap 6; the user's global `CLAUDE.md` hidden | 39/39 | 51/51 |
| 10 | 2026-11-14 | the grouping passes moved to `references/grouping.md`; ASCII follows the repo's history; git's refusals exit 3 | 36/39 | 51/51 |
| 11 | 2026-11-15 | the grouping passes back in `SKILL.md` | 38/39 | 51/51 |

Every `Why:` miss from round 2 on was P2, whose score ran 3, 2, 1, 1, 1, 1, 0, 1, 3, 0, then 2 of 3. Each miss still stated the reason in an ordinary bullet, so it missed the label, not the information.

- **A mechanism is not a cause.** Round 1's wording read: "If a reader who sees the subject would still ask why the change was made, the first bullet is `- Why: <the problem, in one line>`: for a fix, the symptom and its cause; for other types, the need the change answers." Every P1 run wrote a `Why:` restating the off-by-one, and one P6 run left its measured figure in a code comment. Naming the mechanism as not a cause, and saying a comment in the diff does not replace `Why:`, fixed both from round 2 on.
- **A change keeps its tests.** Round 1's grouping line read: "group by related functionality, same module/directory, or same change type." Under it, 7 of 36 runs split a fix or feature from its own tests into a `test` commit. Atomic grouping, from round 3, ended that.
- **A doc binds to the change it describes.** Runs of 0002 and 0004 on the earlier rules put the docs in a `docs` commit of their own, and the 0002 run dropped its `Why:`. The rule then bound two pieces only when "neither can land first and stand", and a doc can always land after its code. No probe fixture carries docs, so round 4 checked only that nothing else moved.
- **A shared source file joins its changes.** A run of 0004 split its two fixes by file and put the shared `AudioCaptureManager.swift` in the later commit, so the first commit's engine restart landed before the conversion it relies on.
- **Only what no order separates binds.** In round 6 one H2 run folded the extracted helper into the feature: "`report_csv.py` imports `rows` from `report.py`. The `rows` refactor in `report.py` therefore can't be committed apart from the CSV feature." The round-6 rules bound two pieces when either alone would break, which counts a one-way dependency. Round 7 bound only what no order can separate, round 8 asked what calls the new piece, and every H2 run since has committed the refactor first.
- **Close calls are weighed by review time.** A run of 0006 gave each of its six coverage-gap test files a commit of its own, eight commits in all. From round 7, one purpose across several targets stays one commit unless review would take about an hour; one round-7 H13 run explained: "the three files together came to 1048 lines, well over an hour of review, so I split them by target."
- **The user's global `CLAUDE.md`.** Rounds 6 to 8 ran with it visible; it holds the user's general working rules and "Always commit changes using the `/git-commit` skill". Whether rounds 1 to 5 saw it is not known; their transcripts are gone. Round 9 hid it and was the first to score P2 3 of 3, but three runs cannot say whether the hidden file or chance moved the score.
- **Grouping stays in `SKILL.md`.** Round 10 moved the five grouping passes into `references/grouping.md`, behind a pointer naming grouped mode, so single-mode and amend runs would not read them. 55 of 57 probe runs read the file and grouping held at 51/51, but fewer summaries named a pass (7 of 57, from 16), P2 lost its `Why:` in all three runs, and 0004's skill arm split its two fixes with the engine restart first, the failure the shared-file rule above records. Four runs a side of 0004 and six of P2, on that skill and on round 9's, gave 0004 joined 2 of 4 against 4 of 4 and P2's `Why:` 2 of 6 against 6 of 6. Round 11 put the passes back; on it, no 0004 run lands a commit that cannot stand, and P2 reaches 6 of 9. Round 9's skill also predates three later commits, so these runs show the passes held better in `SKILL.md`, not that the move alone caused every miss.
