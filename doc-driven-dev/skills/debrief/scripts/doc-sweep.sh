#!/usr/bin/env bash
# doc-sweep.sh — deterministic staleness detector for the /debrief skill.
# Detector half of detector+judge: enumerates candidate findings with high
# recall; the model adjudicates each hit (fix / justify / dismiss) and covers
# the blind spots (session-only decisions, semantic staleness, absences).
#
# Usage (from anywhere inside the project repo):
#   doc-sweep.sh            run the sweep, print a findings report
#   doc-sweep.sh --mark     record HEAD as the baseline for the next sweep
#   DOC_SWEEP_DIR=docs      docs root (default: docs)
#
# Baseline: .claude/last-doc-sweep holds the commit of the last completed
# debrief; the sweep diffs baseline..working-tree. Missing baseline falls
# back to HEAD~5 (or repo root commit) with a warning.
# NOTE: deliberately not `set -e`/pipefail — this is a report generator, and a
# zero-match grep must never abort the remaining sections. Failures are handled
# explicitly where they matter.
set -u

DOCS_DIR="${DOC_SWEEP_DIR:-docs}"
MARK_FILE=".claude/last-doc-sweep"
MAX_TERMS=40

cd "$(git rev-parse --show-toplevel)" || exit 1
[ -d "$DOCS_DIR" ] || { echo "doc-sweep: no '$DOCS_DIR' directory here"; exit 1; }

if [ "${1:-}" = "--mark" ]; then
  mkdir -p "$(dirname "$MARK_FILE")"
  git rev-parse HEAD > "$MARK_FILE"
  echo "doc-sweep: baseline marked at $(cut -c1-12 "$MARK_FILE")"
  exit 0
fi

if [ -f "$MARK_FILE" ] && git cat-file -e "$(cat "$MARK_FILE")^{commit}" 2>/dev/null; then
  BASE="$(cat "$MARK_FILE")"
  BASE_NOTE="baseline $(echo "$BASE" | cut -c1-12) (from $MARK_FILE)"
else
  BASE="$(git rev-parse -q --verify HEAD~5 2>/dev/null || git rev-list --max-parents=0 HEAD | tail -1)"
  BASE_NOTE="FALLBACK baseline $(echo "$BASE" | cut -c1-12) — no $MARK_FILE; run '--mark' after each debrief"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git diff "$BASE" -- "$DOCS_DIR" > "$TMP/diff" || true
grep '^-' "$TMP/diff" 2>/dev/null | grep -v '^---' | sed 's/^-//' > "$TMP/removed" || true
grep '^+' "$TMP/diff" 2>/dev/null | grep -v '^+++' | sed 's/^+//' > "$TMP/added"   || true

echo "== DOC SWEEP =="
echo "$BASE_NOTE"
echo "docs dir: $DOCS_DIR   changed lines: -$(wc -l < "$TMP/removed" | tr -d ' ') +$(wc -l < "$TMP/added" | tr -d ' ')"

# ---- 1. retired-term candidates: tokens/phrases on removed lines, absent from added lines
STOPWORDS='the|this|that|with|from|have|been|would|could|should|their|they|than|then|when|where|which|while|will|into|only|over|after|before|every|each|more|most|some|such|also|does|must|never|once|both|under|between|because|about|other|these|those|there|here|still|just|like|make|made|makes|note|docs|file|files|line|lines|what|whose|your|does|them|been|were|much|many|very|same|then|table|section|example|rule|rules'

tokens() { tr -cs '[:alnum:]' '\n' < "$1" | tr '[:upper:]' '[:lower:]' | awk 'length($0)>=4 && /[a-z]/' | grep -Evw "$STOPWORDS" | sort | uniq -c | sort -rn; }
tokens "$TMP/removed" | awk '{print $2}' > "$TMP/rw" || true
tokens "$TMP/added"   | awk '{print $2}' > "$TMP/aw" || true
comm -23 <(sort -u "$TMP/rw") <(sort -u "$TMP/aw") > "$TMP/cand_words" || true

# phrases: backticked, double-quoted, and bold spans on removed lines, absent from added text
{ grep -o '`[^`]\{4,48\}`'      "$TMP/removed" 2>/dev/null | tr -d '`'  || true
  grep -o '"[^"]\{4,48\}"'      "$TMP/removed" 2>/dev/null | tr -d '"'  || true
  grep -o '\*\*[^*]\{4,48\}\*\*' "$TMP/removed" 2>/dev/null | sed 's/\*//g' || true
} | sort -u > "$TMP/cand_phrases_all"
: > "$TMP/cand_phrases"
while IFS= read -r p; do
  grep -Fqi -- "$p" "$TMP/added" || echo "$p" >> "$TMP/cand_phrases"
done < "$TMP/cand_phrases_all"

cat "$TMP/cand_phrases" "$TMP/cand_words" | awk 'NF' | head -n "$MAX_TERMS" > "$TMP/terms"

echo
echo "== 1. RETIRED-TERM HITS (candidates: $(wc -l < "$TMP/terms" | tr -d ' '), capped at $MAX_TERMS) =="
echo "-- every hit below needs a verdict: FIX or JUSTIFY (frozen artifact / Why-clause history / different sense) --"
FOUND=0
while IFS= read -r t; do
  HITS="$(grep -rni --include='*.md' -F -- "$t" "$DOCS_DIR" 2>/dev/null | head -8 || true)"
  if [ -n "$HITS" ]; then
    FOUND=1
    echo "term: $t"
    echo "$HITS" | sed 's/^/    /'
  fi
done < "$TMP/terms"
[ "$FOUND" = 1 ] || echo "(no corpus hits for any retired-term candidate)"

# ---- 2. referrer closure: who mentions the changed files (and their headings) but wasn't changed
{ git diff --name-only "$BASE" -- "$DOCS_DIR"; git diff --name-only -- "$DOCS_DIR"; } | sort -u | awk 'NF' > "$TMP/changed"
echo
echo "== 2. REFERRERS OF CHANGED DOCS (not themselves changed — check each for lag) =="
if [ -s "$TMP/changed" ]; then
  while IFS= read -r f; do
    b="$(basename "$f")"
    REFS="$(grep -rl --include='*.md' -F -- "$b" "$DOCS_DIR" 2>/dev/null | grep -vxF -f "$TMP/changed" || true)"
    if [ -n "$REFS" ]; then echo "$f is referenced by:"; echo "$REFS" | sed 's/^/    /'; fi
    if [ -f "$f" ]; then
      sed -n 's/^#\{1,3\} \(.*\)/\1/p' "$f" | head -6 | while IFS= read -r h; do
        [ ${#h} -ge 8 ] || continue
        HREFS="$(grep -rl --include='*.md' -F -- "$h" "$DOCS_DIR" 2>/dev/null | grep -vxF "$f" | grep -vxF -f "$TMP/changed" || true)"
        if [ -n "$HREFS" ]; then echo "heading \"$h\" ($f) also appears in:"; echo "$HREFS" | sed 's/^/    /'; fi
      done
    fi
  done < "$TMP/changed"
else
  echo "(no docs changed since baseline)"
fi

# ---- 3. freshness stamps vs last commit dates
echo
echo "== 3. FRESHNESS STAMPS (stamp date older than last commit date = suspect) =="
grep -rn -E 'Updated [0-9]{4}-[0-9]{2}-[0-9]{2}|[Ll]ast audited: ' --include='*.md' "$DOCS_DIR" 2>/dev/null | while IFS=: read -r f n rest; do
  echo "$f:$n  [last commit: $(git log -1 --format=%cs -- "$f" 2>/dev/null || echo '?')]  $rest"
done || echo "(no stamps found)"

# ---- 4. structural: dead links, orphans, oversized files
echo
echo "== 4. STRUCTURAL =="
while IFS= read -r f; do
  d="$(dirname "$f")"
  grep -o '](\([^)#]*\.md\)' "$f" 2>/dev/null | sed 's/](//' | while IFS= read -r l; do
    if [ ! -f "$d/$l" ] && [ ! -f "$l" ]; then echo "dead link in $f -> $l"; fi
  done
done < <(find "$DOCS_DIR" -name '*.md') | sort -u
for idx in $(find "$DOCS_DIR" -name '_index.md'); do
  d="$(dirname "$idx")"
  for f in "$d"/*.md; do
    b="$(basename "$f")"
    [ "$b" = "_index.md" ] && continue
    grep -qF -- "$b" "$idx" || echo "orphan: $f not listed in $idx"
  done
done
find "$DOCS_DIR" -name '*.md' -print0 | xargs -0 wc -l | awk '$1>150 && $2 != "total" {print "over 150 lines: " $2 " (" $1 ")"}'
echo
echo "== END SWEEP — adjudicate every hit above; then append session-decision terms the diff cannot know and grep those too =="
