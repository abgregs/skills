#!/usr/bin/env bash
# doc-sweep.sh — deterministic staleness detector for the /debrief skill.
# Detector half of detector+judge: enumerates candidate findings with high
# recall, each under an ID; the model judges each one (FIX or JUSTIFY) and
# covers the blind spots (session-only decisions, semantic staleness,
# absences). --verdicts is the wall that refuses a summary while a finding
# raised by any sweep of this debrief has no verdict.
#
# Usage (from anywhere inside the project repo):
#   doc-sweep.sh --scope [--base <rev>]   Step 1: pick the base, print it and the change stat
#   doc-sweep.sh [--base <rev>]           the sweep: digest on stdout, full report in a file
#   doc-sweep.sh --verdicts [- | <file>]  add verdicts (from stdin with -), then check every
#                                         finding of this debrief has one
#   doc-sweep.sh --mark [--accept-unjudged]
#                                         record HEAD as the next debrief's base; refused
#                                         while a finding of this debrief has no verdict,
#                                         unless the user accepts it unjudged
#   DOC_SWEEP_DIR=docs                    docs root (default: docs)
#   DOC_SWEEP_BUDGET=20000                digest size cap in bytes
#
# Base, the first that applies: --base; the base --scope picked for this
# debrief; the last debrief's mark when it is an ancestor of HEAD; the legacy
# .claude/last-doc-sweep mark, likewise; the merge-base with the default
# branch, when HEAD has commits past it; HEAD, when the tree has uncommitted
# changes; HEAD~5, which --scope refuses as a guess (exit 4).
# State lives in the git directory, never the working tree: the mark in the
# common dir, shared by every worktree; this worktree's base, findings,
# verdicts, and full report in its own git dir. --scope starts a debrief, so
# it clears the findings and verdicts; every sweep adds its findings to this
# debrief's, so a finding a later sweep no longer sees still needs a verdict;
# --mark ends the debrief and clears the base, findings, and verdicts.
#
# Exit: 0 report printed, or every finding judged; 1 setup (not a git repo,
# no docs dir, bad --base, bad usage); 2 a finding has no verdict or a verdict
# has no reason, from --verdicts or --mark; 3 --verdicts when no sweep has run
# in this worktree, or --scope when nothing changed since the base; 4 --scope
# when the only base is the HEAD~5 guess. Each verdict and refusal names its
# exit code.
# NOTE: deliberately not `set -e`/pipefail — this is a report generator, and a
# zero-match grep must never abort the remaining sections. Failures are handled
# explicitly where they matter.
set -u

DOCS_DIR="${DOC_SWEEP_DIR:-docs}"
BUDGET="${DOC_SWEEP_BUDGET:-20000}"
MAX_TERMS=40
# Names from the code diff have a cap of their own: most never appear in a doc, so they must
# not take the doc terms' places, and each costs only a grep.
MAX_CODE_TERMS=200
DIGEST_HITS=8
REPORT_HITS=50

die() { echo "doc-sweep: $1"; exit 1; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repository; run from the project repo"
cd "$ROOT" || die "cannot enter $ROOT"
GITDIR="$(git rev-parse --absolute-git-dir)"
COMMON="$(cd "$(git rev-parse --git-common-dir)" && pwd)"
MARK="$COMMON/doc-sweep-mark"
LEGACY=".claude/last-doc-sweep"
PENDING="$GITDIR/doc-sweep-base"
FINDINGS="$GITDIR/doc-sweep-findings"
VERDICTS="$GITDIR/doc-sweep-verdicts"
REPORT="$GITDIR/doc-sweep-report.txt"

MODE=sweep; ARG_BASE=""; VFILE=""; ACCEPT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --scope) MODE=scope ;;
    --mark) MODE=mark ;;
    --accept-unjudged) ACCEPT=1 ;;
    --verdicts) MODE=verdicts
      case "${2:-}" in ""|--*) ;; *) VFILE="$2"; shift ;; esac ;;
    --base) ARG_BASE="${2:-}"; [ -n "$ARG_BASE" ] || die "--base needs a revision"; shift ;;
    *) die "unknown argument '$1'; see the usage at the top of this script" ;;
  esac
  shift
done

# ---- the verdict check: every finding of this debrief needs '<ID> FIX|JUSTIFY <reason>'.
# Lines from every --verdicts call of this debrief count; the latest line for an ID wins.
check_verdicts() {
  touch "$VERDICTS"
  awk -F'\t' -v vf="$VERDICTS" '
    BEGIN {
      while ((getline line < vf) > 0) {
        if (!match(line, /[TRFS]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f](-[0-9]+)?/)) continue
        id = substr(line, RSTART, RLENGTH); rest = substr(line, RSTART + RLENGTH)
        if (!match(toupper(rest), /^[^A-Z]*(FIX|JUSTIFY)/)) continue
        why = substr(rest, RLENGTH + 1); gsub(/^[^A-Za-z0-9]+/, "", why)
        seen[id] = 1; reason[id] = (length(why) > 0)
      }
    }
    { n++
      if (!($1 in seen))   { print "UNJUDGED   " $1 "  " $2; bad++ }
      else if (!reason[$1]) { print "NO REASON  " $1 "  the verdict must say what changed or why it stays"; bad++ } }
    END {
      if (n == 0) print "doc-sweep: no sweep of this debrief raised a finding; nothing to judge (exit 0)"
      else if (bad) printf "doc-sweep: %d of the %d findings of this debrief lack a verdict; send one line per ID above with --verdicts - (exit 2)\n", bad, n
      else printf "doc-sweep: all %d findings of this debrief judged (exit 0)\n", n
      exit (bad ? 2 : 0)
    }' "$FINDINGS"
}

# ---- --mark: the next debrief starts here, once every finding is judged
if [ "$MODE" = mark ]; then
  if [ -f "$FINDINGS" ] && [ "$ACCEPT" = 0 ]; then
    check_verdicts || { echo "doc-sweep: --mark refused: judge the findings above first; only the user can accept them unjudged, with --mark --accept-unjudged (exit 2)"; exit 2; }
  fi
  git rev-parse HEAD > "$MARK" || die "cannot write $MARK"
  rm -f "$PENDING" "$VERDICTS" "$FINDINGS"
  echo "doc-sweep: mark set at $(cut -c1-12 "$MARK") in $MARK, shared by every worktree"
  [ -f "$LEGACY" ] && echo "doc-sweep: $LEGACY is no longer needed; delete it and its .gitignore line"
  exit 0
fi

# ---- --verdicts: add this call's lines, then check
if [ "$MODE" = verdicts ]; then
  [ -f "$FINDINGS" ] || { echo "doc-sweep: no sweep has run in this worktree; run the sweep, then --verdicts (exit 3)"; exit 3; }
  if [ "$VFILE" = "-" ]; then cat >> "$VERDICTS"
  elif [ -n "$VFILE" ]; then
    [ -f "$VFILE" ] || die "no verdicts file at $VFILE"
    cat "$VFILE" >> "$VERDICTS"
  fi
  check_verdicts
  exit $?
fi

# ---- the base, shared by --scope and the sweep
is_commit() { git rev-parse -q --verify "$1^{commit}" >/dev/null 2>&1; }
ancestor() { git merge-base --is-ancestor "$1" HEAD 2>/dev/null; }
default_branch() {
  local r
  r="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)" && { echo "$r"; return; }
  for r in origin/main origin/master main master; do is_commit "$r" && { echo "$r"; return; }; done
}
SKIPPED=""; GUESS=0
resolve_base() {
  local m c db mb
  if [ -n "$ARG_BASE" ]; then
    is_commit "$ARG_BASE" || die "--base '$ARG_BASE' is not a commit in this repo"
    BASE="$(git rev-parse "$ARG_BASE^{commit}")"; SRC="--base $ARG_BASE"; return
  fi
  if [ "$MODE" = sweep ] && [ -f "$PENDING" ]; then
    c="$(cat "$PENDING")"
    if is_commit "$c" && ancestor "$c"; then BASE="$c"; SRC="the base --scope picked for this debrief"; return; fi
  fi
  for m in "$MARK" "$LEGACY"; do
    [ -f "$m" ] || continue
    c="$(cat "$m")"
    is_commit "$c" || continue
    if ancestor "$c"; then BASE="$(git rev-parse "$c^{commit}")"; SRC="the last debrief's mark in $m"; return; fi
    SKIPPED="${SKIPPED:+$SKIPPED; }the mark in $m is not an ancestor of HEAD, so another branch's debrief made it"
  done
  db="$(default_branch)"
  if [ -n "$db" ]; then
    mb="$(git merge-base HEAD "$db" 2>/dev/null)"
    if [ -n "$mb" ] && [ "$mb" != "$(git rev-parse HEAD)" ]; then BASE="$mb"; SRC="merge-base with $db"; return; fi
  fi
  # No mark and no commits past the branch point: uncommitted work is the
  # change; a clean tree leaves only a guess, which --scope refuses to use.
  if dirty; then
    BASE="$(git rev-parse HEAD)"
    SRC="HEAD: no mark and no commits past the branch point, so only uncommitted changes are reviewed; pass --base <rev> to include earlier commits"
    return
  fi
  BASE="$(git rev-parse -q --verify HEAD~5 2>/dev/null || git rev-list --max-parents=0 HEAD | tail -1)"
  SRC="FALLBACK HEAD~5: no mark, no commits past the branch point, and a clean tree"; GUESS=1
}
dirty() { [ -n "$(git status --porcelain 2>/dev/null | head -1)" ]; }
short() { printf '%s' "$1" | cut -c1-12; }

# ---- --scope: Step 1's facts, and the base the sweep reuses
if [ "$MODE" = scope ]; then
  resolve_base
  rm -f "$VERDICTS" "$PENDING" "$FINDINGS"
  N="$(git rev-list --count "$BASE"..HEAD)"
  if [ "$N" = 0 ] && ! dirty; then
    echo "doc-sweep: nothing changed since $(short "$BASE") ($SRC): no commits, no uncommitted changes, no untracked files."
    echo "doc-sweep: nothing to debrief; tell the user to commit or edit first, or to name a range for --base <rev> (exit 3)"
    exit 3
  fi
  if [ "$GUESS" = 1 ]; then
    echo "doc-sweep: no reliable base: no mark, no commits past the branch point, and a clean tree."
    echo "doc-sweep: the last 5 commits would only be a guess; ask the user which range to review, then run --scope --base <rev> (exit 4)"
    echo
    echo "== RECENT COMMITS, to offer as a start =="
    git log --oneline -10
    exit 4
  fi
  echo "$BASE" > "$PENDING"
  echo "== DOC SWEEP SCOPE =="
  echo "base: $(short "$BASE")  ($SRC)"
  [ -n "$SKIPPED" ] && echo "note: $SKIPPED"
  echo
  echo "== COMMITS SINCE BASE ($N) =="
  git log --oneline "$BASE"..HEAD | head -30
  [ "$N" -gt 30 ] && echo "(+$((N - 30)) older)"
  echo
  echo "== CHANGE STAT, committed and uncommitted =="
  git diff --stat "$BASE" | tail -40
  UL="$GITDIR/doc-sweep-untracked"
  git ls-files --others --exclude-standard > "$UL"
  NU="$(awk 'END { print NR }' "$UL")"
  if [ "$NU" -gt 0 ]; then
    echo; echo "== UNTRACKED FILES ($NU): not in git diff; Read each one =="
    head -30 "$UL"
    [ "$NU" -gt 30 ] && echo "(+$((NU - 30)) more, listed in $UL)"
  fi
  echo
  READ="read the change with: git diff $(short "$BASE")"
  [ "$NU" -gt 0 ] && READ="$READ, and Read the untracked files above"
  echo "== END SCOPE — $READ; the sweep in Step 5 reuses this base =="
  exit 0
fi

# ---- the sweep
# With no docs folder, the rules in CLAUDE.md or AGENTS.md are still worth a sweep.
[ -d "$DOCS_DIR" ] || [ -f CLAUDE.md ] || [ -f AGENTS.md ] || die "no '$DOCS_DIR' directory, CLAUDE.md, or AGENTS.md here; set DOC_SWEEP_DIR to the docs root"
resolve_base

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
D="$TMP/digest"; F="$TMP/findings"
: > "$D"; : > "$REPORT"; : > "$F"
dg() { printf '%s\n' "$@" >> "$D"; }
rp() { printf '%s\n' "$@" >> "$REPORT"; }
both() { dg "$@"; rp "$@"; }
# finding <kind> <key> <description>: an ID stable across reruns, from its key
finding() {
  local id
  id="$1-$(printf '%s' "$2" | cksum | awk '{ printf "%04x", $1 % 65536 }')"
  printf '%s\t%s\n' "$id" "$3" >> "$F"
  LAST_ID="$id"
}

# Root instruction files hold rules too, so they are diffed and searched with the docs.
ROOTDOCS=""; for f in CLAUDE.md AGENTS.md; do [ -f "$f" ] && ROOTDOCS="$ROOTDOCS $f"; done
git diff "$BASE" -- "$DOCS_DIR" $ROOTDOCS > "$TMP/diff" || true
# The code diff: a name or literal the code dropped is retired when no added line, code or
# doc, still uses it; this is what a change to code alone gives the sweep to work from.
git diff "$BASE" -- . ":(exclude)$DOCS_DIR" ':(exclude)*.md' > "$TMP/cdiff" || true
grep '^-' "$TMP/cdiff" 2>/dev/null | grep -v '^---' | sed 's/^-//' > "$TMP/cremoved" || true
grep '^+' "$TMP/cdiff" 2>/dev/null | grep -v '^+++' | sed 's/^+//' > "$TMP/cadded" || true
grep '^-' "$TMP/diff" 2>/dev/null | grep -v '^---' | sed 's/^-//' > "$TMP/removed" || true
# Text from **Why:** to the end of its line records what a rule replaced, so it names old terms
# on purpose: it neither keeps a term alive on an added line nor counts as a stale use below.
grep '^+' "$TMP/diff" 2>/dev/null | grep -v '^+++' | sed 's/^+//; s/\*\*Why:\*\*.*//' > "$TMP/added" || true

# ---- 1. retired-term candidates: phrases and words on removed lines that no added line uses:
# doc phrases, then short terms, then names from the code diff, then doc words by how often they
# were removed, so the cap keeps the strongest
STOPWORDS='the|this|that|with|from|have|been|would|could|should|their|they|than|then|when|where|which|while|will|into|only|over|after|before|every|each|more|most|some|such|also|does|must|never|once|both|under|between|because|about|other|these|those|there|here|still|just|like|make|made|makes|note|docs|file|files|line|lines|what|whose|your|them|were|much|many|very|same|table|section|example|rule|rules'
tokens() { tr -cs '[:alnum:]' '\n' < "$1" | tr '[:upper:]' '[:lower:]' | awk 'length($0)>=4 && /[a-z]/' | grep -Evw "$STOPWORDS" | sort | uniq -c; }
tokens "$TMP/removed" > "$TMP/rw" || true
tokens "$TMP/added" | awk '{ print $2 }' > "$TMP/aw" || true
awk 'FILENAME == ARGV[1] { a[$1]; next } !($2 in a) { print $1, $2 }' "$TMP/aw" "$TMP/rw" | sort -k1,1nr -k2,2 | awk '{ print $2 }' > "$TMP/cand_words"

{ grep -o '`[^`]\{2,48\}`'       "$TMP/removed" 2>/dev/null | tr -d '`'  || true
  grep -o '"[^"]\{4,48\}"'       "$TMP/removed" 2>/dev/null | tr -d '"'  || true
  grep -o '\*\*[^*]\{4,48\}\*\*' "$TMP/removed" 2>/dev/null | sed 's/\*//g' || true
} | sort -u > "$TMP/cand_phrases_all"
: > "$TMP/cand_phrases"
while IFS= read -r p; do
  if [ ${#p} -lt 4 ]; then grep -Fqiw -- "$p" "$TMP/added"; else grep -Fqi -- "$p" "$TMP/added"; fi || echo "$p" >> "$TMP/cand_phrases"
done < "$TMP/cand_phrases_all"
# Short terms: acronyms of three to six capitals (JWT, OAUTH), which the word list skips.
: > "$TMP/cand_short"
tr -cs '[:alnum:]' '\n' < "$TMP/removed" | grep -E '^[A-Z][A-Z0-9][A-Z0-9][A-Z0-9]?[A-Z0-9]?[A-Z0-9]?$' | sort -u | while IFS= read -r p; do
  grep -Fqiw -- "$p" "$TMP/added" || echo "$p" >> "$TMP/cand_short"
done
# Names from the code diff: string literals, and identifiers in snake_case, kebab-case, or camelCase.
cat "$TMP/added" "$TMP/cadded" > "$TMP/alladded"
{ grep -oE '"[^"]{3,48}"' "$TMP/cremoved" 2>/dev/null | tr -d '"' || true
  grep -oE "'[^']{3,48}'" "$TMP/cremoved" 2>/dev/null | tr -d "'" || true
  grep -oE '[A-Za-z][A-Za-z0-9]*([_-][A-Za-z0-9]+)+' "$TMP/cremoved" 2>/dev/null || true
  grep -oE '[a-z][a-z0-9]*[A-Z][A-Za-z0-9]*' "$TMP/cremoved" 2>/dev/null || true
} | sed 's/^ *//; s/ *$//' | grep '[A-Za-z]' | awk 'length($0) >= 3' | sort -u > "$TMP/code_all"
: > "$TMP/cand_code"
while IFS= read -r p; do
  if [ ${#p} -lt 4 ]; then grep -Fqiw -- "$p" "$TMP/alladded"; else grep -Fqi -- "$p" "$TMP/alladded"; fi || echo "$p" >> "$TMP/cand_code"
done < "$TMP/code_all"

# A backticked word is also a word: keep its first appearance only.
cat "$TMP/cand_phrases" "$TMP/cand_short" "$TMP/cand_words" | awk 'NF && !seen[tolower($0)]++' > "$TMP/cand_doc"
# Terms only the code diff gave, labelled so a doc reader looks for them in the code.
tr '[:upper:]' '[:lower:]' < "$TMP/cand_doc" > "$TMP/doc_terms"
awk 'FILENAME == ARGV[1] { d[$0]; next } !(tolower($0) in d) && !seen[tolower($0)]++' "$TMP/doc_terms" "$TMP/cand_code" > "$TMP/code_only"
{ head -n "$MAX_TERMS" "$TMP/cand_doc"; head -n "$MAX_CODE_TERMS" "$TMP/code_only"; } > "$TMP/terms"
{ tail -n +"$((MAX_TERMS + 1))" "$TMP/cand_doc"; tail -n +"$((MAX_CODE_TERMS + 1))" "$TMP/code_only"; } > "$TMP/dropped"
NCAND="$(cat "$TMP/cand_doc" "$TMP/code_only" | wc -l | tr -d ' ')"
NTERMS="$(wc -l < "$TMP/terms" | tr -d ' ')"
NDROP="$(wc -l < "$TMP/dropped" | tr -d ' ')"

: > "$TMP/s1d"; : > "$TMP/s1r"
while IFS= read -r t; do
  # A short term matches as a whole word only, so `api` does not match "rapid".
  WORD=""; [ ${#t} -lt 4 ] && WORD=-w
  grep -rniH --include='*.md' -F $WORD -- "$t" "$DOCS_DIR" $ROOTDOCS 2>/dev/null \
    | awk -v t="$t" '{ s = $0; i = index(s, "**Why:**"); if (i) s = substr(s, 1, i - 1); if (index(tolower(s), tolower(t))) print }' \
    | cut -c1-200 > "$TMP/hits" || true
  n="$(wc -l < "$TMP/hits" | tr -d ' ')"
  [ "$n" -gt 0 ] || continue
  finding T "term:$t" "term '$t' is still used $n times, first at $(head -1 "$TMP/hits" | cut -d: -f1-2)"
  FROM=""; grep -qxF -- "$t" "$TMP/code_only" && FROM="  from the code diff"
  printf '%s  term: %s  (%s hits)%s\n' "$LAST_ID" "$t" "$n" "$FROM" | tee -a "$TMP/s1r" >> "$TMP/s1d"
  head -n "$DIGEST_HITS" "$TMP/hits" | sed 's/^/    /' >> "$TMP/s1d"
  [ "$n" -gt "$DIGEST_HITS" ] && echo "    (+$((n - DIGEST_HITS)) more in the full report)" >> "$TMP/s1d"
  head -n "$REPORT_HITS" "$TMP/hits" | sed 's/^/    /' >> "$TMP/s1r"
done < "$TMP/terms"

# ---- 2. referrers: docs that name a changed doc or repeat one of its headings, but were not changed
{ git diff --name-only "$BASE" -- "$DOCS_DIR"; git ls-files --others --exclude-standard -- "$DOCS_DIR"; } | sort -u | awk 'NF' > "$TMP/changed"
: > "$TMP/s2"
while IFS= read -r f; do
  [ -e "$f" ] || continue   # a deleted doc's referrers are found below, with what became of it
  b="$(basename "$f")"
  grep -rl --include='*.md' -F -- "$b" "$DOCS_DIR" $ROOTDOCS 2>/dev/null | grep -vxF -f "$TMP/changed" | while IFS= read -r ref; do
    finding R "ref:$f:$ref" "$ref names $f, which changed; check it for lag"
    echo "$LAST_ID  $ref names changed $f" >> "$TMP/s2"
  done
  [ -f "$f" ] || continue
  sed -n 's/^#\{1,3\} \(.*\)/\1/p' "$f" | head -6 | while IFS= read -r h; do
    [ ${#h} -ge 8 ] || continue
    grep -rl --include='*.md' -F -- "$h" "$DOCS_DIR" 2>/dev/null | grep -vxF "$f" | grep -vxF -f "$TMP/changed" | while IFS= read -r ref; do
      finding R "head:$f:$h:$ref" "$ref repeats the heading '$h' of $f, which changed"
      echo "$LAST_ID  $ref repeats heading \"$h\" of changed $f" >> "$TMP/s2"
    done
  done
done < "$TMP/changed"
# A doc the change renamed or deleted: every unchanged doc that still names its old path.
git diff --name-status -M "$BASE" -- "$DOCS_DIR" 2>/dev/null | awk -F'\t' '$1 ~ /^R/ { print $2 "\t" $3 } $1 == "D" { print $2 "\t" }' > "$TMP/gone"
while IFS="$(printf '\t')" read -r old new; do
  if [ -n "$new" ]; then what="renamed to $new"; else what="deleted"; fi
  grep -rl --include='*.md' -F -- "$(basename "$old")" "$DOCS_DIR" $ROOTDOCS 2>/dev/null | grep -vxF -f "$TMP/changed" | while IFS= read -r ref; do
    finding R "gone:$old:$ref" "$ref names $old, which this change $what"
    echo "$LAST_ID  $ref names $old, $what" >> "$TMP/s2"
  done
done < "$TMP/gone"

# ---- 3. freshness: an 'Updated YYYY-MM-DD' stamp older than its file's last commit
: > "$TMP/s3"
grep -rn -E 'Updated [0-9]{4}-[0-9]{2}-[0-9]{2}' --include='*.md' "$DOCS_DIR" 2>/dev/null > "$TMP/stamps" || true
while IFS=: read -r f n rest; do
  s="$(printf '%s' "$rest" | grep -oE 'Updated [0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 | cut -d' ' -f2)"
  c="$(git log -1 --format=%cs -- "$f" 2>/dev/null)"
  if [ -n "$c" ] && [ "$s" \< "$c" ]; then
    finding F "stamp:$f:$s" "$f:$n says Updated $s, but the file last changed $c"
    echo "$LAST_ID  $f:$n  stamp $s, last commit $c" >> "$TMP/s3"
  fi
done < "$TMP/stamps"
NSTAMPS="$(wc -l < "$TMP/stamps" | tr -d ' ')"

# --- docs structure checks (identical block in debrief/scripts/doc-sweep.sh and setup-docs/scripts/docs-audit.sh; scripts/check-shared-blocks.sh fails on drift) ---
# needs from the caller: nothing. structure_faults <docs-dir> prints one fault
# per line, each starting with its kind; DOCS_MAX_LINES is the docs contract's
# file limit, stated in the SKILL.md docs contract block.
DOCS_MAX_LINES=150
structure_faults() {
  local docs="$1" f d l b idx rest
  find "$docs" -name '*.md' -type f | LC_ALL=C sort | while IFS= read -r f; do
    d="$(dirname "$f")"
    grep -o '](\([^)#]*\.md\)' "$f" 2>/dev/null | sed 's/^](//' | while IFS= read -r l; do
      case "$l" in http://*|https://*) continue ;; esac
      [ -f "$d/$l" ] || [ -f "$l" ] || echo "dead link: $f -> $l"
    done
  done | LC_ALL=C sort -u
  find "$docs" -name '*.md' -type f -exec dirname {} \; | LC_ALL=C sort -u | while IFS= read -r d; do
    idx="$d/_index.md"
    if [ ! -f "$idx" ]; then
      echo "no index: $d holds $(find "$d" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ') docs and no _index.md"
      continue
    fi
    for f in "$d"/*.md; do
      b="$(basename "$f")"
      [ "$b" = "_index.md" ] && continue
      grep -qF -- "$b" "$idx" || echo "orphan: $f is not listed in $idx"
    done
    # An entry's summary sits on its own line, or on the next one under a heading entry.
    awk -v idx="$idx" '
      { line[NR] = $0 }
      END {
        for (i = 1; i <= NR; i++) {
          if (line[i] !~ /\.md/) continue
          r = line[i]; gsub(/\[[^]]*\]\([^)]*\)/, "", r); gsub(/`[^`]*`/, "", r)
          gsub(/[A-Za-z0-9._\/-]+\.md/, "", r); gsub(/[^A-Za-z]+/, " ", r)
          if (split(r, w, " ") >= 2) continue
          n = line[i + 1]
          if (n !~ /^[ \t]*([-*|#>]|$)/ && split(n, w2, " ") >= 2) continue
          print "no summary: " idx ":" i " names a doc with no summary"
        }
      }' "$idx"
  done
  find "$docs" -name '*.md' -type f | LC_ALL=C sort | while IFS= read -r f; do
    l="$(wc -l < "$f" | tr -d ' ')"
    [ "$l" -gt "$DOCS_MAX_LINES" ] && echo "over $DOCS_MAX_LINES lines: $f ($l)"
  done
}
# --- end docs structure checks ---

# ---- 4. structure: a fault in a doc (or the folder of a doc) changed since the base
# is a finding of this debrief; faults elsewhere stand, listed without IDs.
: > "$TMP/s4"
if [ -d "$DOCS_DIR" ]; then structure_faults "$DOCS_DIR" > "$TMP/faults"; else : > "$TMP/faults"; fi
# getline, not NR == FNR: an empty changed list would make awk read the faults as the list.
awk -v chf="$TMP/changed" 'BEGIN { while ((getline c < chf) > 0) { ch[c] = 1; d = c; sub(/\/[^\/]*$/, "", d); dir[d] = 1 } }
  { f = ""
    if ($1 == "dead") f = $3
    else if ($1 == "orphan:") f = $2
    else if ($1 == "no" && $2 == "index:") f = $3
    else if ($1 == "no" && $2 == "summary:") { f = $3; sub(/:[0-9]+$/, "", f) }
    else if ($1 == "over") f = $4
    rel = (f in ch) || (f in dir) || ($1 == "orphan:" && ($NF in ch))
    print (rel ? "C" : "O") "\t" $0 }' "$TMP/faults" > "$TMP/faults.tagged"
grep '^O' "$TMP/faults.tagged" | cut -f2- > "$TMP/standing" || true
grep '^C' "$TMP/faults.tagged" | cut -f2- | while IFS= read -r fault; do
  finding S "$fault" "$fault"
  echo "$LAST_ID  $fault" >> "$TMP/s4"
done
NSTANDING="$(wc -l < "$TMP/standing" | tr -d ' ')"

# ---- 5. cross-cutting axes, for the axis audit (not findings)
grep -n -iE 'last audited:' "$DOCS_DIR/_index.md" 2>/dev/null > "$TMP/axes" || true

# Two findings with one key would share an ID; number the repeats.
awk -F'\t' 'BEGIN { OFS = "\t" } { c[$1]++; if (c[$1] > 1) $1 = $1 "-" c[$1]; print }' "$F" > "$TMP/this"
# This debrief's findings: an ID is stable across sweeps, so a repeat is one finding, and one
# a later sweep no longer raises (fixed, or hidden by an edit) still needs its verdict.
touch "$FINDINGS"
awk -F'\t' 'FILENAME == ARGV[1] { had[$1]; print; next } !($1 in had)' "$FINDINGS" "$TMP/this" > "$TMP/all" && cat "$TMP/all" > "$FINDINGS"
NTHIS="$(awk 'END { print NR }' "$TMP/this")"; NALL="$(awk 'END { print NR }' "$FINDINGS")"
# The section files carry the unnumbered IDs; renumber repeats there the same way.
for s in s1d s1r s2 s3 s4; do
  awk '{ if (match($0, /^[TRFS]-[0-9a-f]+/)) { id = substr($0, 1, RLENGTH); c[id]++; if (c[id] > 1) $0 = id "-" c[id] substr($0, RLENGTH + 1) } print }' "$TMP/$s" > "$TMP/$s.n"
done
count() { grep -c "^$1-" "$TMP/this" | tr -d ' '; }

# ---- assemble the digest and the full report
both "== DOC SWEEP =="
both "base: $(short "$BASE")  ($SRC)"
[ -n "$SKIPPED" ] && both "note: $SKIPPED"
SWEPT="$DOCS_DIR"; [ -d "$DOCS_DIR" ] || SWEPT="no $DOCS_DIR folder"; [ -n "$ROOTDOCS" ] && SWEPT="$SWEPT +$ROOTDOCS"
both "docs: $SWEPT   doc lines changed since base: -$(wc -l < "$TMP/removed" | tr -d ' ') +$(wc -l < "$TMP/added" | tr -d ' ')   full report: $REPORT"
both "findings: $(count T) retired-term, $(count R) referrer, $(count F) freshness, $(count S) structure; each needs a verdict (see the end)"
[ "$NALL" -gt "$NTHIS" ] && both "this debrief: $NALL findings across its sweeps; $((NALL - NTHIS)) raised earlier still need a verdict, though this sweep no longer shows them"
both "" "== 1. RETIRED TERMS ($NTERMS of $NCAND candidates checked: up to $MAX_TERMS from the docs, phrases and acronyms first, then words most removed; up to $MAX_CODE_TERMS names from the code diff) =="
if [ -s "$TMP/s1d.n" ]; then cat "$TMP/s1d.n" >> "$D"; cat "$TMP/s1r.n" >> "$REPORT"; else both "(no corpus hits for any candidate)"; fi
if [ "$NDROP" -gt 0 ]; then
  both "dropped by the caps of $MAX_TERMS doc and $MAX_CODE_TERMS code terms ($NDROP): $(head -30 "$TMP/dropped" | tr '\n' ' ')$([ "$NDROP" -gt 30 ] && echo '…')"
  rp "all dropped candidates:"; sed 's/^/    /' "$TMP/dropped" >> "$REPORT"
fi
rp "all candidates checked:"; sed 's/^/    /' "$TMP/terms" >> "$REPORT"
both "" "== 2. REFERRERS OF CHANGED DOCS (not themselves changed) =="
if [ -s "$TMP/changed" ]; then
  if [ -s "$TMP/s2.n" ]; then cat "$TMP/s2.n" >> "$D"; cat "$TMP/s2.n" >> "$REPORT"; else both "(no unchanged doc names a changed one)"; fi
else both "(no docs changed since base)"; fi
both "" "== 3. FRESHNESS STAMPS ($NSTAMPS 'Updated' stamps) =="
if [ "$NSTAMPS" -eq 0 ]; then both "(no stamps found)"
elif [ -s "$TMP/s3.n" ]; then cat "$TMP/s3.n" >> "$D"; cat "$TMP/s3.n" >> "$REPORT"
else both "(every stamp is as new as its file's last commit)"; fi
[ "$NSTAMPS" -gt 0 ] && { rp "all stamps:"; sed 's/^/    /' "$TMP/stamps" >> "$REPORT"; }
both "" "== 4. STRUCTURE IN DOCS THIS CHANGE TOUCHED =="
if [ -s "$TMP/s4.n" ]; then cat "$TMP/s4.n" >> "$D"; cat "$TMP/s4.n" >> "$REPORT"; else both "(no dead links, orphans, missing indexes, summary-less entries, or files over $DOCS_MAX_LINES lines)"; fi
if [ "$NSTANDING" -gt 0 ]; then
  both "standing faults in docs this change did not touch ($NSTANDING; no verdict needed, a source for the 1-2 structural improvements):"
  head -10 "$TMP/standing" | sed 's/^/    /' >> "$D"
  [ "$NSTANDING" -gt 10 ] && dg "    (+$((NSTANDING - 10)) more in the full report)"
  sed 's/^/    /' "$TMP/standing" >> "$REPORT"
fi
both "" "== 5. CROSS-CUTTING AXES in $DOCS_DIR/_index.md (for the axis audit; not findings) =="
if [ -s "$TMP/axes" ]; then cat "$TMP/axes" >> "$D"; cat "$TMP/axes" >> "$REPORT"; else both "(no 'last audited:' lines; the axis audit creates the section)"; fi
END="== END SWEEP — judge every finding ID, one line each: '<ID> FIX <what changed>' or '<ID> JUSTIFY <reason>', sent with: doc-sweep.sh --verdicts - <<'EOF' ... EOF; grep the session-decision terms the diff cannot know =="
rp "" "$END"

# The digest stays under the budget; what it cuts is in the full report, and
# --verdicts still holds every finding ID.
sec() { grep -E '^== [0-9]+\. ' | sed -E 's/^== ([0-9]+)\. ([A-Z][A-Z -]*[A-Z]).*/\1 (\2)/'; }
SIZE="$(wc -c < "$D" | tr -d ' ')"
if [ "$SIZE" -gt "$BUDGET" ]; then
  head -c "$BUDGET" "$D" | sed '$d'
  PART="$(head -c "$BUDGET" "$D" | sec | tail -1)"
  GONE="$(tail -c +"$((BUDGET + 1))" "$D" | sec | paste -sd, - | sed 's/,/, /g')"
  echo "== DIGEST CUT at $BUDGET of $SIZE bytes, inside section $PART; not shown: ${GONE:-the rest of that section}. Read them in $REPORT; it holds every finding ID =="
else
  cat "$D"
fi
echo
echo "$END"
