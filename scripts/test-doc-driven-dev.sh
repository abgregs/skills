#!/usr/bin/env bash
# test-doc-driven-dev.sh — repo tooling, not part of any skill.
#
# Regression cases for the doc-driven-dev detectors: brief's doc-scout.sh,
# debrief's doc-sweep.sh (the base, the term cap, findings and --verdicts,
# structure, the digest budget), and setup-docs's docs-audit.sh, plus the
# docs contract they share. Lives here, not in a skill folder, because the
# skills CLI copies a skill's whole folder to every user who installs it.
#
# Each case runs in a throwaway repo under $TMPDIR. DOC_SCOUT, DOC_SWEEP, and
# DOCS_AUDIT point the suite at other copies of the scripts, so a deliberately
# broken copy shows which cases turn red without editing the real one.
#
# Usage: bash scripts/test-doc-driven-dev.sh   (exit 1 on any failing case)
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
G="$REPO/doc-driven-dev/skills"
SCOUT="${DOC_SCOUT:-$G/brief/scripts/doc-scout.sh}"
SWEEP="${DOC_SWEEP:-$G/debrief/scripts/doc-sweep.sh}"
AUDIT="${DOCS_AUDIT:-$G/setup-docs/scripts/docs-audit.sh}"
W="$(mktemp -d "${TMPDIR:-/tmp}/test-doc-driven-dev.XXXXXX")"
PASS=0; FAILS=0
trap '[ "$FAILS" = 0 ] && rm -rf "$W" || echo "kept $W for inspection"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

# ---- case helpers: t runs one command; the others add checks; ok reports
t() { NAME="$1"; WANT="$2"; shift 2; OUT="$("$@" 2>&1)"; RC=$?; WHY=""
      [ "$RC" = "$WANT" ] || WHY="exit $RC, want $WANT"; }
why() { WHY="${WHY:+$WHY; }$1"; }
has() { printf '%s\n' "$OUT" | grep -qE -- "$1" || why "no output matching: $1"; }
lacks() { printf '%s\n' "$OUT" | grep -qE -- "$1" && why "unexpected output: $1"; }
before() { local a b; a="$(printf '%s\n' "$OUT" | grep -nE -- "$1" | head -1 | cut -d: -f1)"
           b="$(printf '%s\n' "$OUT" | grep -nE -- "$2" | head -1 | cut -d: -f1)"
           [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ] || why "'$1' (line ${a:-none}) is not before '$2' (line ${b:-none})"; }
size_under() { local n; n="$(printf '%s\n' "$OUT" | wc -c | tr -d ' ')"; [ "$n" -le "$1" ] || why "output is $n bytes, want at most $1"; }
ok() { if [ -z "$WHY" ]; then PASS=$((PASS + 1)); echo "PASS  $NAME"
       else FAILS=$((FAILS + 1)); echo "FAIL  $NAME — $WHY"; printf '%s\n' "$OUT" | head -60 | sed 's/^/        | /'; fi; }

# repo <name>: a fresh repo on main with one commit
repo() { local d="$W/$1"; mkdir -p "$d"; cd "$d" || exit 1; git init -q -b main; echo x > README.md; git add README.md; git commit -qm start; }
commit() { git add -A; git commit -qm "${1:-change}"; }
# corpus <folders> <entries>: docs/<folder>/_index.md with that many summarised entries, and the docs
corpus() {
  local i j d
  mkdir -p docs; printf '# Docs\n\n' > docs/_index.md
  for i in $(seq 1 "$1"); do
    d="docs/area-$i"; mkdir -p "$d"; printf '# Area %s\n\n' "$i" > "$d/_index.md"
    printf -- '- [area-%s](area-%s/_index.md): the docs for area number %s\n' "$i" "$i" "$i" >> docs/_index.md
    for j in $(seq 1 "$2"); do
      printf '# Topic %s\n\nPlain text about topic %s.\n' "$j" "$j" > "$d/topic-$j.md"
      printf -- '- [topic-%s.md](topic-%s.md): notes on topic %s in area %s, with a long summary line\n' "$j" "$j" "$j" "$i" >> "$d/_index.md"
    done
  done
}
findings() { cat "$(git rev-parse --absolute-git-dir)/doc-sweep-findings"; }

# ============================== doc-scout (brief)

repo scout-large; corpus 40 30
mkdir -p docs/caching
printf '# Cache invalidation\n\n## Rules\n- Purge on write.\n  **Why:** stale reads cost a refund.\n' > docs/caching/cache-invalidation.md
printf '# Caching\n\n- [cache-invalidation.md](cache-invalidation.md): when and how the cache is purged\n' > docs/caching/_index.md
commit
t "scout: a 1,200-entry corpus stays under the digest budget" 0 bash "$SCOUT" cache invalidation
size_under 21000; has 'term-hits: docs/caching/cache-invalidation.md'
before '== 1\. RELEVANCE SHORTLIST' '== 3\. INDEX ENTRIES'
before 'term-hits: docs/caching' '== 3\. INDEX ENTRIES'
has 'Why:\*\* stale reads'; has 'docs/caching/_index.md \(1 entries, 1 match'; ok
t "scout: the full report keeps every index whole" 0 grep -c 'with a long summary line' "$(git rev-parse --absolute-git-dir)/doc-scout-report.txt"
has '^1200$'; ok
t "scout: with no terms every index prints, so the budget cuts and names the report" 0 env DOC_SCOUT_BUDGET=5000 bash "$SCOUT"
size_under 5600; has 'DIGEST CUT at 5000'; has 'doc-scout-report.txt'; has 'END SCOUT'
has 'inside section 3 \(INDEX ENTRIES\); not shown: 4 \(ROOT INSTRUCTION FILES\), 5 \(INVENTORY\)'; ok

repo scout-nodocs
t "scout: no docs dir with terms given says so, not 'no terms'" 0 bash "$SCOUT" caching layer
has "no 'docs' directory"; has 'skipped: no docs directory'; lacks 'no task terms'; ok
t "scout: words under four letters are named as unusable" 0 bash "$SCOUT" ui db
has 'none usable'; ok
mkdir -p "$W/nogit"; cd "$W/nogit" || exit 1
t "scout: outside a git repo it scans the current directory" 0 bash "$SCOUT" caching
has 'not a git repository'; ok

# ============================== doc-sweep (debrief): the term cap

repo sweep-cap; mkdir -p docs
{ for i in $(seq 1 46); do printf 'lightword%02d ' "$i"; done; printf '\nzzheavy zzheavy zzheavy zzheavy zzheavy\n'; } > docs/a.md
printf 'we still say zzheavy and lightword46 here, a summary.\n' > docs/b.md
printf -- '- [a.md](a.md): the old words in a list\n- [b.md](b.md): a doc that still uses them\n' > docs/_index.md
commit base; echo "new text only" > docs/a.md; commit change
t "sweep: the cap keeps the most-removed term, whatever its letter" 0 bash "$SWEEP" --base HEAD~1
has 'T-[0-9a-f]{4}  term: zzheavy'; has 'dropped by the cap of 40 \(7\)'; has 'dropped.*lightword46'; lacks 'term: lightword46'; ok

repo sweep-dup; mkdir -p docs
printf -- '- [a.md](a.md): the doc that renames\n- [b.md](b.md): the doc that lags\n' > docs/_index.md
echo 'its folder is a `workspace` row' > docs/a.md; echo "a workspace can be archived" > docs/b.md; commit base
echo 'its folder is a `folders` row' > docs/a.md; commit rename
t "sweep: a term found as a phrase and as a word is one finding" 0 bash "$SWEEP" --base HEAD~1
has 'term: workspace'; lacks 'T-[0-9a-f]{4}-2'; ok

# ============================== stamps

repo sweep-stamps; mkdir -p docs; printf -- '- [a.md](a.md): a doc with no stamp\n' > docs/_index.md; echo "plain" > docs/a.md; commit
t "sweep: a corpus with no stamps says so" 0 bash "$SWEEP" --base HEAD~1
has '\(no stamps found\)'; ok
printf 'Updated 2000-01-01\n' >> docs/a.md; commit stamp
t "sweep: a stamp older than its file's last commit is a finding" 0 bash "$SWEEP" --base HEAD~1
has 'F-[0-9a-f]{4}  docs/a.md:2  stamp 2000-01-01'; ok

# ============================== the base: worktrees, the shared mark, --scope

repo sweep-base; mkdir -p docs; printf -- '- [a.md](a.md): a doc that changes on the branch\n' > docs/_index.md; echo v0 > docs/a.md; commit base
C0="$(git rev-parse HEAD)"
git worktree add -q -b feat "$W/sweep-base-feat"
cd "$W/sweep-base-feat" || exit 1
for i in 1 2 3 4 5 6 7 8; do echo "v$i" >> docs/a.md; commit "step $i"; done
t "sweep: a fresh worktree with no mark uses the merge-base, not HEAD~5" 0 bash "$SWEEP"
has "base: $(printf '%s' "$C0" | cut -c1-12)  \(merge-base with main\)"; lacks FALLBACK; ok

cd "$W/sweep-base" || exit 1; echo more > docs/b.md; printf -- '- [b.md](b.md): a doc added on main later\n' >> docs/_index.md; commit "main moves"
bash "$SWEEP" --mark > /dev/null
cd "$W/sweep-base-feat" || exit 1
t "sweep: another branch's mark is skipped, and the note says why" 0 bash "$SWEEP"
has 'merge-base with main'; has 'not an ancestor of HEAD'; ok
cd "$W/sweep-base" || exit 1; git checkout -q "$C0" 2>/dev/null; bash "$SWEEP" --mark > /dev/null; git checkout -q main
cd "$W/sweep-base-feat" || exit 1
t "sweep: the mark is shared by every worktree when it is an ancestor" 0 bash "$SWEEP"
has "the last debrief's mark in .*doc-sweep-mark"; ok
t "sweep: --scope records the base it prints" 0 bash "$SWEEP" --scope --base HEAD~3
has "base: $(git rev-parse --short=12 HEAD~3)  \(--base HEAD~3\)"; has '== COMMITS SINCE BASE \(3\)'; has 'git diff [0-9a-f]{12}'; ok
t "sweep: the sweep reuses the base --scope picked" 0 bash "$SWEEP"
has "base: $(git rev-parse --short=12 HEAD~3)  \(the base --scope picked"; ok
bash "$SWEEP" --mark --accept-unjudged > /dev/null
t "sweep: --mark clears this debrief's base" 0 bash "$SWEEP"
has "the last debrief's mark"; lacks 'the base --scope picked'; ok
t "sweep: --mark writes nothing into the working tree" 0 git status --porcelain
lacks '.'; ok

repo sweep-legacy; mkdir -p docs .claude; printf -- '- [a.md](a.md): a doc for the legacy mark\n' > docs/_index.md; echo v0 > docs/a.md; commit base
git rev-parse HEAD > .claude/last-doc-sweep; echo v1 >> docs/a.md; commit next
t "sweep: the legacy .claude mark is still read" 0 bash "$SWEEP"
has "mark in .claude/last-doc-sweep"; ok
t "sweep: --mark says the legacy file can go" 0 bash "$SWEEP" --mark --accept-unjudged
has 'no longer needed'; ok

# ============================== setup errors

t "sweep: a --base that is not a commit stops with exit 1" 1 bash "$SWEEP" --base nosuchrev
has "is not a commit"; ok
repo sweep-nodocs
t "sweep: no docs dir stops with exit 1" 1 bash "$SWEEP"
has "no 'docs' directory"; ok
cd "$W/nogit" || exit 1
t "sweep: outside a git repo stops with exit 1" 1 bash "$SWEEP"
has 'not inside a git repository'; ok

# ============================== structure

repo sweep-structure; mkdir -p docs/guides docs/conventions
printf '# Conventions\n\n- [style.md](style.md): how the code is styled here\n- [bare.md](bare.md)\n' > docs/conventions/_index.md
echo "see [gone](missing.md) and [web](https://example.com/x.md)" > docs/conventions/style.md
echo "bare" > docs/conventions/bare.md; echo "orphan" > docs/conventions/lost.md
seq 1 151 > docs/conventions/long.md; printf -- '- [long.md](long.md): a file past the limit\n' >> docs/conventions/_index.md
echo guide > docs/guides/start.md
printf -- '- [conventions](conventions/_index.md): how code is written\n' > docs/_index.md
commit
t "sweep: structure finds the five faults the contract names" 0 bash "$SWEEP" --base HEAD~1
has 'S-[0-9a-f]{4}  dead link: docs/conventions/style.md -> missing.md'; lacks 'example.com'
has 'orphan: docs/conventions/lost.md'; has 'no index: docs/guides holds 1 docs'
has 'no summary: docs/conventions/_index.md:4'; has 'over 150 lines: docs/conventions/long.md \(151\)'; ok
printf '## [guides/](guides/start.md)\nHow to get started with the project.\n' >> docs/_index.md
echo "a small edit" >> docs/conventions/style.md; commit "touch style only"
t "sweep: faults outside the change stand, without IDs" 0 bash "$SWEEP" --base HEAD~1
has 'S-[0-9a-f]{4}  dead link: docs/conventions/style.md'; has 'standing faults in docs this change did not touch'
has '^    over 150 lines: docs/conventions/long.md'; lacks 'S-[0-9a-f]{4}  over 150'
lacks 'no summary: docs/_index.md'; ok
t "sweep: with no doc changed, every fault stands" 0 bash "$SWEEP" --base HEAD
has 'standing faults in docs this change did not touch \(5;'; lacks 'S-[0-9a-f]{4} '; ok

# ============================== findings and --verdicts

repo sweep-verdicts
t "sweep: --verdicts before any sweep exits 3" 3 bash "$SWEEP" --verdicts /dev/null
has 'no sweep has run'; ok
mkdir -p docs; printf -- '- [a.md](a.md): a doc whose term retires\n- [b.md](b.md): a doc still using it\n' > docs/_index.md
echo "use the flibber cache" > docs/a.md; echo "the flibber cache also" > docs/b.md; commit base
echo "use the store" > docs/a.md; commit retire
bash "$SWEEP" --base HEAD~1 > /dev/null; FIRST="$(findings)"
bash "$SWEEP" --base HEAD~1 > /dev/null
t "sweep: finding IDs are stable across reruns" 0 test "$FIRST" = "$(findings)"
[ -n "$FIRST" ] || why "the fixture produced no findings"; ok
IDS="$(findings | cut -f1)"
: > "$W/v-empty"
t "sweep: --verdicts names every unjudged finding and exits 2" 2 bash "$SWEEP" --verdicts "$W/v-empty"
for id in $IDS; do has "UNJUDGED   $id"; done; ok
for id in $IDS; do echo "$id JUSTIFY"; done > "$W/v-bare"
t "sweep: a verdict with no reason is refused" 2 bash "$SWEEP" --verdicts "$W/v-bare"
has 'NO REASON'; ok
for id in $IDS; do echo "- $id: FIX reworded b.md to the new store term"; done > "$W/v-full"
t "sweep: every finding judged passes, the latest line for an ID winning" 0 bash "$SWEEP" --verdicts "$W/v-full"
has 'all [0-9]+ findings judged'; ok
t "sweep: --verdicts with nothing new rechecks the verdicts already given" 0 bash "$SWEEP" --verdicts
has 'all [0-9]+ findings judged'; ok
bash "$SWEEP" --scope --base HEAD~1 > /dev/null
t "sweep: --scope starts a debrief, so earlier verdicts no longer count" 2 bash "$SWEEP" --verdicts
has 'UNJUDGED'; ok
FIRST_ID="$(printf '%s\n' $IDS | head -1)"
t "sweep: verdicts read from stdin with -" 2 bash -c "printf '%s FIX done\n' $FIRST_ID | bash '$SWEEP' --verdicts -"
lacks "UNJUDGED   $FIRST_ID"; has '\(exit 2\)$'; ok
MARKFILE="$(git rev-parse --git-common-dir)/doc-sweep-mark"
t "sweep: --mark is refused while a finding has no verdict" 2 bash "$SWEEP" --mark
has 'UNJUDGED'; has '--mark refused'; has 'accept-unjudged'
[ -f "$MARKFILE" ] && why "the mark was written anyway"; ok
for id in $IDS; do echo "$id FIX done"; done | bash "$SWEEP" --verdicts - > /dev/null
t "sweep: --mark passes once every finding is judged" 0 bash "$SWEEP" --mark
has 'baseline marked'; [ -f "$MARKFILE" ] || why "no mark written"; ok
t "sweep: --mark ends the debrief, so its findings are gone" 3 bash "$SWEEP" --verdicts
has '\(exit 3\)'; ok
bash "$SWEEP" --base HEAD~1 > /dev/null
t "sweep: the user's override marks with findings unjudged" 0 bash "$SWEEP" --mark --accept-unjudged
has 'baseline marked'; ok

# ============================== the digest budget

repo sweep-budget; mkdir -p docs
{ for i in $(seq 1 40); do printf 'retiredterm%02d\n' "$i"; done; } > docs/a.md
for j in $(seq 1 30); do { for i in $(seq 1 40); do printf 'retiredterm%02d is a long line of padding text for the budget test\n' "$i"; done; } > "docs/user-$j.md"; done
{ for j in a $(seq 1 30); do [ "$j" = a ] && f=a.md || f="user-$j.md"; printf -- '- [%s](%s): a doc for the budget test\n' "$f" "$f"; done; } > docs/_index.md
commit base; echo "nothing old" > docs/a.md; commit retire
t "sweep: an over-budget digest is cut, and says where the rest is" 0 env DOC_SWEEP_BUDGET=3000 bash "$SWEEP" --base HEAD~1
size_under 3800; has 'DIGEST CUT at 3000'; has 'END SWEEP'; ok
t "sweep: the full report holds every finding ID" 0 bash -c 'r="$(git rev-parse --absolute-git-dir)"; n=0; for id in $(cut -f1 "$r/doc-sweep-findings"); do grep -q "^$id " "$r/doc-sweep-report.txt" || n=$((n + 1)); done; echo "missing $n"'
has '^missing 0$'; ok

# ============================== docs-audit (setup-docs)

repo audit; mkdir -p docs/Guides docs/conventions
echo "# Guide" > docs/Guides/MyDoc.md; echo "notes" > notes.md
printf -- '- [style.md](style.md): how the code is styled\n' > docs/conventions/_index.md; echo style > docs/conventions/style.md
printf '# Rules\n## Build\n' > CLAUDE.md; echo '{}' > package.json
commit
t "audit: reports the contract's gaps, names, and docs outside docs/" 0 bash "$AUDIT"
has 'missing  docs/requirements'; has 'missing  docs/_index.md'; has 'docs/Guides/MyDoc.md'
has '^ +1  notes.md'; has 'no index: docs/Guides'; has '--- CLAUDE.md \(2 lines\)'; has 'package.json'
before '== 2\. STRUCTURE FAULTS' '== 8\. INVENTORY'; ok
cd "$W/nogit" || exit 1
t "audit: outside a git repo it scans the current directory" 0 bash "$AUDIT"
has 'not a git repository'; ok

# ============================== the docs contract the skills share

cd "$REPO" || exit 1
t "contract: the shared blocks match across the three skills and two scripts" 0 bash scripts/check-shared-blocks.sh
lacks 'DRIFT'; ok
LIMIT="$(sed -n 's/^DOCS_MAX_LINES=\([0-9]*\)$/\1/p' "$SWEEP" | head -1)"
t "contract: the SKILL.md limit is the scripts' DOCS_MAX_LINES" 0 grep -c "at most $LIMIT lines" "$G/brief/SKILL.md" "$G/debrief/SKILL.md" "$G/setup-docs/SKILL.md"
lacks ':0$'; ok

echo
echo "$PASS passed, $FAILS failed"
[ "$FAILS" = 0 ]
