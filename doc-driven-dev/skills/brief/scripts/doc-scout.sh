#!/usr/bin/env bash
# doc-scout.sh — deterministic doc-discovery detector for the /brief skill.
# Detector half of detector+judge: enumerates the doc corpus and shortlists
# task-relevant files with high recall; the model judges applicability, reads
# the shortlisted docs in full, and extracts the rules.
#
# Usage (from anywhere inside the project repo; outside git it scans the
# current directory):
#   doc-scout.sh <task words...>   digest: shortlist, Why-lines, matching index entries
#   doc-scout.sh                   digest without a shortlist (no task to match)
#   DOC_SCOUT_DIR=docs             docs root (default: docs)
#   DOC_SCOUT_BUDGET=20000         digest size cap in bytes
#
# Output: a digest under the budget, findings first, then a full report
# (every index in full, every doc with its size) at the path the digest
# names. The digest's size follows the shortlist, not the corpus.
# Exit 0 always: /brief never blocks on missing docs, so neither does this.
# NOTE: no `set -e`/pipefail — this is a report generator; a zero-match grep
# must never abort remaining sections.
set -u

DOCS_DIR="${DOC_SCOUT_DIR:-docs}"
BUDGET="${DOC_SCOUT_BUDGET:-20000}"
SHORTLIST=12
INDEX_LINES=15

if ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  cd "$ROOT" || exit 0
  REPORT="$(git rev-parse --absolute-git-dir)/doc-scout-report.txt"
  NOTE=""
else
  ROOT="$PWD"
  REPORT="$(mktemp "${TMPDIR:-/tmp}/doc-scout-report.XXXXXX")"
  NOTE="not a git repository; scanning from $ROOT"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
D="$TMP/digest"
: > "$D"; : > "$REPORT"
dg() { printf '%s\n' "$@" >> "$D"; }
rp() { printf '%s\n' "$@" >> "$REPORT"; }
both() { dg "$@"; rp "$@"; }

HAVE_DOCS=0; [ -d "$DOCS_DIR" ] && HAVE_DOCS=1

STOPWORDS='the|this|that|with|from|have|been|would|could|should|their|when|where|which|while|will|into|only|over|after|before|every|each|more|most|some|such|also|does|must|make|made|need|needs|task|code|file|files|add|adds|added|new|use|using|update|updated'
: > "$TMP/terms"
[ "$#" -gt 0 ] && echo "$*" | tr -cs '[:alnum:]' '\n' | tr '[:upper:]' '[:lower:]' \
  | awk 'length($0)>=4 && /[a-z]/' | grep -Evw "$STOPWORDS" | sort -u > "$TMP/terms"
HAVE_TERMS=0; [ -s "$TMP/terms" ] && HAVE_TERMS=1

both "== DOC SCOUT =="
[ -n "$NOTE" ] && both "$NOTE"
if [ "$HAVE_DOCS" = 1 ]; then
  NDOCS="$(find "$DOCS_DIR" -name '*.md' -type f | wc -l | tr -d ' ')"
  NDIRS="$(find "$DOCS_DIR" -name '*.md' -type f -exec dirname {} \; | sort -u | wc -l | tr -d ' ')"
  both "docs: $DOCS_DIR, $NDOCS docs in $NDIRS folders"
else
  both "no '$DOCS_DIR' directory: fall back to CLAUDE.md/AGENTS.md below; consider /setup-docs"
fi
if [ "$HAVE_TERMS" = 1 ]; then both "task terms: $(tr '\n' ' ' < "$TMP/terms")"
elif [ "$#" -gt 0 ]; then both "task terms: none usable (each needs four or more characters)"
else both "task terms: none given, so no shortlist"; fi
both "full report: $REPORT"

# ---- 1. relevance shortlist: how many task terms each doc mentions
both "" "== 1. RELEVANCE SHORTLIST (term hits: how many task terms the doc mentions) =="
: > "$TMP/short"
if [ "$HAVE_DOCS" = 0 ]; then both "(skipped: no docs directory)"
elif [ "$HAVE_TERMS" = 0 ]; then both "(skipped: no task terms; triage from the index entries below)"
else
  : > "$TMP/hits"
  while IFS= read -r t; do
    grep -rli --include='*.md' -F -- "$t" "$DOCS_DIR" 2>/dev/null >> "$TMP/hits" || true
  done < "$TMP/terms"
  if [ -s "$TMP/hits" ]; then
    sort "$TMP/hits" | uniq -c | sort -k1,1rn -k2,2 | head -n "$SHORTLIST" > "$TMP/short"
    awk '{ printf "  %s term-hits: %s\n", $1, $2 }' "$TMP/short" | tee -a "$REPORT" >> "$D"
  else
    both "  (no term hits; judge relevance from the index entries below)"
  fi
fi

# ---- 2. headings and Why-lines of the shortlisted files: the rule menu's spine
both "" "== 2. HEADINGS AND WHY-LINES OF SHORTLISTED FILES =="
if [ -s "$TMP/short" ]; then
  awk '{ print $2 }' "$TMP/short" | while IFS= read -r f; do
    both "--- $f ($(wc -l < "$f" | tr -d ' ') lines) ---"
    grep -n -E '^#{1,3} |\*\*Why:?\*\*' "$f" | head -25 | cut -c1-220 | sed 's/^/    /' | tee -a "$REPORT" >> "$D"
  done
else
  both "(no shortlist)"
fi

# ---- 3. index entries: the triage layer. The digest keeps the entries that
# name a task term or a shortlisted file; the report keeps every index whole.
both "" "== 3. INDEX ENTRIES (digest: entries matching the task; full report: every index whole) =="
if [ "$HAVE_DOCS" = 1 ]; then
  awk '{ print $2 }' "$TMP/short" | while IFS= read -r f; do basename "$f"; done > "$TMP/match"
  cat "$TMP/terms" >> "$TMP/match"
  find "$DOCS_DIR" -name '_index.md' -type f | LC_ALL=C sort | while IFS= read -r idx; do
    TOTAL="$(grep -c '\.md' "$idx" | tr -d ' ')"
    rp "--- $idx ---"; cat "$idx" >> "$REPORT"; rp ""
    if [ "$HAVE_TERMS" = 0 ]; then
      dg "--- $idx ($TOTAL entries) ---"; cat "$idx" >> "$D"; dg ""
      continue
    fi
    if [ -s "$TMP/match" ]; then grep -n -i -F -f "$TMP/match" "$idx" | head -n "$INDEX_LINES" > "$TMP/idxhit"; else : > "$TMP/idxhit"; fi
    SHOWN="$(wc -l < "$TMP/idxhit" | tr -d ' ')"
    dg "--- $idx ($TOTAL entries, $SHOWN match the task) ---"
    cut -c1-220 "$TMP/idxhit" | sed 's/^/    /' >> "$D"
  done
  NIDX="$(find "$DOCS_DIR" -name '_index.md' -type f | wc -l | tr -d ' ')"
  [ "$NIDX" -gt 0 ] || both "(no _index.md files)"
else
  both "(no docs directory)"
fi

# ---- 4. root instruction files: their rules count even when no term matches
both "" "== 4. ROOT INSTRUCTION FILES (their rules count even with no term match; read them in full) =="
FOUND=0
for f in CLAUDE.md AGENTS.md; do
  [ -f "$f" ] || continue
  FOUND=1
  both "--- $f ($(wc -l < "$f" | tr -d ' ') lines) ---"
  rp "$(head -200 "$f")"
  if [ "$HAVE_DOCS" = 0 ]; then
    head -80 "$f" >> "$D"
  else
    grep -n '^#' "$f" | head -30 | sed 's/^/    /' >> "$D"
    if [ "$HAVE_TERMS" = 1 ]; then
      grep -n -i -F -f "$TMP/terms" "$f" | grep -v ':#' | head -20 | cut -c1-220 | sed 's/^/    match /' >> "$D"
    fi
  fi
done
[ "$FOUND" = 1 ] || both "(no CLAUDE.md or AGENTS.md at the root)"

# ---- 5. inventory: folder counts in the digest, every doc in the report
both "" "== 5. INVENTORY (digest: docs per folder; full report: every doc and its lines) =="
if [ "$HAVE_DOCS" = 1 ]; then
  find "$DOCS_DIR" -name '*.md' -type f | LC_ALL=C sort > "$TMP/all"
  awk '{ n = split($0, p, "/"); d = p[1]; for (i = 2; i < n; i++) d = d "/" p[i]; c[d]++ } END { for (d in c) printf "%5d  %s/\n", c[d], d }' "$TMP/all" | LC_ALL=C sort -k2 >> "$D"
  while IFS= read -r f; do printf '%5d  %s\n' "$(wc -l < "$f")" "$f"; done < "$TMP/all" >> "$REPORT"
else
  both "(none)"
fi

END="== END SCOUT — this is the floor, not the ceiling: READ the shortlisted docs in full, follow their cross-references, and cite file:line for every rule you carry into the plan =="
rp "" "$END"

# The digest stays under the budget; what it cuts is in the full report, and
# the cut line names the sections it leaves out.
sec() { grep -E '^== [0-9]+\. ' | sed -E 's/^== ([0-9]+)\. ([A-Z][A-Z -]*[A-Z]).*/\1 (\2)/'; }
SIZE="$(wc -c < "$D" | tr -d ' ')"
if [ "$SIZE" -gt "$BUDGET" ]; then
  head -c "$BUDGET" "$D" | sed '$d'
  PART="$(head -c "$BUDGET" "$D" | sec | tail -1)"
  GONE="$(tail -c +"$((BUDGET + 1))" "$D" | sec | paste -sd, - | sed 's/,/, /g')"
  echo "== DIGEST CUT at $BUDGET of $SIZE bytes, inside section $PART; not shown: ${GONE:-the rest of that section}. Read them in $REPORT =="
else
  cat "$D"
fi
echo
echo "$END"
