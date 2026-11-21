#!/usr/bin/env bash
# docs-audit.sh — deterministic docs inventory for the /setup-docs skill.
# Detector half of detector+judge: counts what Step 1's assessment needs
# (which parts of the docs contract exist, every doc and its size, structure
# faults, names, docs outside docs/, the root instruction files, the axes
# section, and the codebase's top level); the model judges what to keep,
# relocate, split, merge, or remove.
#
# Usage (from anywhere inside the project; outside git it scans the current
# directory):
#   docs-audit.sh
#   DOCS_AUDIT_DIR=docs        docs root (default: docs)
#   DOCS_AUDIT_BUDGET=20000    digest size cap in bytes
#
# Output: a digest under the budget; when it is cut, the full report is at
# the path it names.
# Exit 0 always: an audit of a project with no docs is a normal start.
# NOTE: no `set -e`/pipefail — this is a report generator; a zero-match grep
# must never abort remaining sections.
set -u

DOCS_DIR="${DOCS_AUDIT_DIR:-docs}"
BUDGET="${DOCS_AUDIT_BUDGET:-20000}"

if ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  cd "$ROOT" || exit 0
  REPORT="$(git rev-parse --absolute-git-dir)/docs-audit-report.txt"
  GIT=1; NOTE=""
else
  ROOT="$PWD"; GIT=0
  REPORT="$(mktemp "${TMPDIR:-/tmp}/docs-audit-report.XXXXXX")"
  NOTE="not a git repository; scanning from $ROOT"
fi
: > "$REPORT"
rp() { printf '%s\n' "$@" >> "$REPORT"; }

# Files the project tracks, or everything outside the usual build folders.
listed() {
  if [ "$GIT" = 1 ]; then git ls-files --cached --others --exclude-standard
  else find . -type f -not -path '*/.git/*' -not -path '*/node_modules/*' | sed 's|^\./||'; fi
}

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

rp "== DOCS AUDIT =="
[ -n "$NOTE" ] && rp "$NOTE"
rp "root: $ROOT   docs dir: $DOCS_DIR   full report: $REPORT"

# ---- 1. the contract's structure: what exists
rp "" "== 1. TARGET STRUCTURE =="
for p in "$DOCS_DIR" "$DOCS_DIR/_index.md" "$DOCS_DIR/conventions" "$DOCS_DIR/architecture" "$DOCS_DIR/requirements" "$DOCS_DIR/planning"; do
  if [ -e "$p" ]; then rp "present  $p"; else rp "missing  $p"; fi
done
for c in conventions architecture requirements planning; do
  [ -d "$DOCS_DIR/$c" ] && [ ! -f "$DOCS_DIR/$c/_index.md" ] && rp "missing  $DOCS_DIR/$c/_index.md"
done

# ---- 2. structure faults
rp "" "== 2. STRUCTURE FAULTS =="
if [ -d "$DOCS_DIR" ]; then
  FAULTS="$(structure_faults "$DOCS_DIR")"
  if [ -n "$FAULTS" ]; then printf '%s\n' "$FAULTS" >> "$REPORT"; else rp "(none)"; fi
else rp "(no $DOCS_DIR directory)"; fi

# ---- 3. names that are not kebab-case
rp "" "== 3. NAMES NOT KEBAB-CASE =="
BAD=""
[ -d "$DOCS_DIR" ] && BAD="$(find "$DOCS_DIR" -name '*.md' -type f | LC_ALL=C sort | while IFS= read -r f; do
  b="$(basename "$f" .md)"
  [ "$b" = "_index" ] && continue
  printf '%s' "$b" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' || echo "$f"
done)"
if [ -n "$BAD" ]; then printf '%s\n' "$BAD" >> "$REPORT"; else rp "(none)"; fi

# ---- 4. Markdown outside the docs dir: candidates to relocate
rp "" "== 4. MARKDOWN OUTSIDE $DOCS_DIR/ (relocation candidates; README, CHANGELOG, LICENSE, CONTRIBUTING, CLAUDE, AGENTS left out) =="
OUT="$(listed | grep -iE '\.md$' | grep -v "^$DOCS_DIR/" \
  | grep -viE '(^|/)(readme|changelog|license|licence|contributing|code_of_conduct|security|claude|agents)\.md$' \
  | grep -vE '(^|/)(node_modules|vendor|\.github|\.claude)/' | LC_ALL=C sort | head -60)"
if [ -n "$OUT" ]; then
  printf '%s\n' "$OUT" | while IFS= read -r f; do printf '%5d  %s\n' "$(wc -l < "$f" 2>/dev/null || echo 0)" "$f"; done >> "$REPORT"
else rp "(none)"; fi

# ---- 5. root instruction files: input to the migration check
rp "" "== 5. ROOT INSTRUCTION FILES =="
FOUND=0
for f in CLAUDE.md AGENTS.md; do
  [ -f "$f" ] || continue
  FOUND=1
  rp "--- $f ($(wc -l < "$f" | tr -d ' ') lines), headings:"
  grep -n '^#' "$f" | head -40 | sed 's/^/    /' >> "$REPORT"
done
[ "$FOUND" = 1 ] || rp "(no CLAUDE.md or AGENTS.md at the root)"

# ---- 6. cross-cutting axes
rp "" "== 6. CROSS-CUTTING AXES in $DOCS_DIR/_index.md =="
if [ -f "$DOCS_DIR/_index.md" ] && grep -q '^## Cross-cutting axes' "$DOCS_DIR/_index.md"; then
  sed -n '/^## Cross-cutting axes/,/^## /p' "$DOCS_DIR/_index.md" | sed '1d;/^## /d' | awk 'NF' >> "$REPORT"
else rp "(no '## Cross-cutting axes' section yet)"; fi

# ---- 7. codebase top level: where to look for conventions
rp "" "== 7. CODEBASE MAP (top-level folders by file count; manifests) =="
listed | awk -F/ 'NF > 1 { c[$1]++ } END { for (d in c) printf "%6d  %s/\n", c[d], d }' | sort -rn | head -20 >> "$REPORT"
MAN="$(listed | grep -E '(^|/)(package\.json|pnpm-workspace\.yaml|Cargo\.toml|pyproject\.toml|requirements\.txt|go\.mod|Gemfile|Package\.swift|build\.gradle(\.kts)?|pom\.xml|composer\.json|mix\.exs|deno\.jsonc?|wrangler\.(toml|jsonc?)|Makefile|Dockerfile|tsconfig\.json)$' | grep -vE '(^|/)node_modules/' | head -20)"
if [ -n "$MAN" ]; then rp "manifests and build files:"; printf '%s\n' "$MAN" | sed 's/^/    /' >> "$REPORT"; fi
XC="$(listed | grep -oE '^[^/]*\.xcodeproj' | sort -u | head -5)"
[ -n "$XC" ] && rp "Xcode projects: $(printf '%s' "$XC" | tr '\n' ' ')"

# ---- 8. every doc with its size, last because it is the longest section
rp "" "== 8. INVENTORY (lines  path) =="
if [ -d "$DOCS_DIR" ]; then
  N="$(find "$DOCS_DIR" -name '*.md' -type f | wc -l | tr -d ' ')"
  rp "$N docs"
  find "$DOCS_DIR" -name '*.md' -type f | LC_ALL=C sort | while IFS= read -r f; do
    printf '%5d  %s\n' "$(wc -l < "$f")" "$f" >> "$REPORT"
  done
  OTHER="$(find "$DOCS_DIR" -type f -not -name '*.md' | head -20)"
  [ -n "$OTHER" ] && { rp "non-Markdown files in $DOCS_DIR:"; printf '%s\n' "$OTHER" | sed 's/^/    /' >> "$REPORT"; }
else
  rp "(no $DOCS_DIR directory)"
fi

END="== END AUDIT — judge each doc in the inventory: keep, relocate, split, merge, or remove; nothing above is a verdict =="
rp "" "$END"

# The cut line names the sections the digest leaves out.
sec() { grep -E '^== [0-9]+\. ' | sed -E 's/^== ([0-9]+)\. ([A-Z][A-Z -]*[A-Z]).*/\1 (\2)/'; }
SIZE="$(wc -c < "$REPORT" | tr -d ' ')"
if [ "$SIZE" -gt "$BUDGET" ]; then
  head -c "$BUDGET" "$REPORT" | sed '$d'
  PART="$(head -c "$BUDGET" "$REPORT" | sec | tail -1)"
  GONE="$(tail -c +"$((BUDGET + 1))" "$REPORT" | sec | paste -sd, - | sed 's/,/, /g')"
  echo "== DIGEST CUT at $BUDGET of $SIZE bytes, inside section $PART; not shown: ${GONE:-the rest of that section}. Read them in $REPORT =="
  echo
  echo "$END"
else
  cat "$REPORT"
fi
