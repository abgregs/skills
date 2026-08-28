#!/usr/bin/env bash
# doc-scout.sh — deterministic doc-discovery detector for the /brief skill.
# Detector half of detector+judge: enumerates the doc corpus and shortlists
# task-relevant files with high recall; the model judges applicability, reads
# the shortlisted docs in full, and extracts the rules.
#
# Usage (from anywhere inside the project repo):
#   doc-scout.sh <task words...>   inventory + relevance shortlist + Why-lines
#   doc-scout.sh                   inventory only (no task to match against)
#   DOC_SCOUT_DIR=docs             docs root (default: docs)
#
# NOTE: no `set -e`/pipefail — this is a report generator; a zero-match grep
# must never abort remaining sections.
set -u

DOCS_DIR="${DOC_SCOUT_DIR:-docs}"
cd "$(git rev-parse --show-toplevel)" || exit 1

echo "== DOC SCOUT =="
if [ ! -d "$DOCS_DIR" ]; then
  echo "no '$DOCS_DIR' directory — fall back to CLAUDE.md/AGENTS.md below; consider /setup-docs"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---- 1. inventory: every doc with line count
echo
echo "== 1. INVENTORY =="
if [ -d "$DOCS_DIR" ]; then
  find "$DOCS_DIR" -name '*.md' | sort | while IFS= read -r f; do
    printf '%5d  %s\n' "$(wc -l < "$f")" "$f"
  done
else
  echo "(none)"
fi

# ---- 2. indexes: the triage layer, printed in full
echo
echo "== 2. INDEX SUMMARIES (triage from these before opening files) =="
if [ -d "$DOCS_DIR" ]; then
  find "$DOCS_DIR" -name '_index.md' | sort | while IFS= read -r idx; do
    echo "--- $idx ---"
    cat "$idx"
    echo
  done
fi

# ---- 3. root instruction files
echo "== 3. ROOT INSTRUCTION FILES =="
for f in CLAUDE.md AGENTS.md; do
  if [ -f "$f" ]; then
    echo "--- $f (first 80 lines) ---"
    head -80 "$f"
    echo
  fi
done

# ---- 4. relevance shortlist: task terms vs corpus
STOPWORDS='the|this|that|with|from|have|been|would|could|should|their|when|where|which|while|will|into|only|over|after|before|every|each|more|most|some|such|also|does|must|make|made|need|needs|task|code|file|files|add|adds|added|new|use|using|update|updated'
if [ "$#" -gt 0 ] && [ -d "$DOCS_DIR" ]; then
  echo "$*" | tr -cs '[:alnum:]' '\n' | tr '[:upper:]' '[:lower:]' \
    | awk 'length($0)>=4 && /[a-z]/' | grep -Evw "$STOPWORDS" | sort -u > "$TMP/terms"
  echo "== 4. RELEVANCE SHORTLIST (task terms: $(tr '\n' ' ' < "$TMP/terms")) =="
  : > "$TMP/hits"
  while IFS= read -r t; do
    grep -rli --include='*.md' -F -- "$t" "$DOCS_DIR" 2>/dev/null >> "$TMP/hits" || true
  done < "$TMP/terms"
  if [ -s "$TMP/hits" ]; then
    sort "$TMP/hits" | uniq -c | sort -rn | head -12 | tee "$TMP/short" \
      | awk '{printf "  %s term-hits: %s\n", $1, $2}'
  else
    echo "  (no term hits — judge relevance from the index summaries above)"
  fi

  # ---- 5. headings + Why-lines from shortlisted files (the rule menu's spine)
  echo
  echo "== 5. HEADINGS AND WHY-LINES OF SHORTLISTED FILES =="
  awk '{print $2}' "$TMP/short" 2>/dev/null | while IFS= read -r f; do
    echo "--- $f ---"
    grep -n -E '^#{1,3} |\*\*Why:?\*\*' "$f" | head -25 | sed 's/^/    /'
  done
else
  echo "== 4. RELEVANCE SHORTLIST == (skipped — no task terms given)"
fi

echo
echo "== END SCOUT — this is the floor, not the ceiling: READ the shortlisted docs in full, follow their cross-references, and cite file:line for every rule you carry into the plan =="
