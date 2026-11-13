#!/usr/bin/env bash
# check-evidence.sh — repo tooling, not part of any skill.
#
# Evidence cases record the skill they ran on as a content hash, so a later
# edit to the skill shows up here instead of hiding behind a sentence like
# "as committed with these cases". The hash covers what the agent can read
# at run time: SKILL.md, scripts/, examples/, and references/.
#
# Each skill's evidence/README.md carries, in a table whose header row starts
# with "| Item |", a row:
#     | Skill hash | `<12 hex>` | `<12 hex>` |      one cell per batch column;
#                                                  the first backticked hash in
#                                                  a cell counts, prose may follow
#
# Usage:
#   bash scripts/check-evidence.sh            report each batch: current or STALE
#   bash scripts/check-evidence.sh --hash <skill-dir>
#                                             print a skill's hash, to record a new batch
# Exit 1 only when a README has no hash row; a stale batch is reported, not
# failed, since editing a skill after its evidence is normal.
set -u

cd "$(git rev-parse --show-toplevel)" || exit 1
if command -v shasum >/dev/null 2>&1; then SHA="shasum -a 256"; else SHA="sha256sum"; fi

skill_hash() { # <skill-dir>
  ( cd "$1" && find SKILL.md scripts examples references -type f -not -name '.*' 2>/dev/null \
      | LC_ALL=C sort | while IFS= read -r f; do printf '%s\n' "$f"; cat "$f"; done ) \
    | $SHA | cut -c1-12
}

if [ "${1:-}" = "--hash" ]; then
  [ -n "${2:-}" ] && [ -f "$2/SKILL.md" ] || { echo "usage: check-evidence.sh --hash <skill-dir>"; exit 1; }
  skill_hash "$2"; exit 0
fi

FAIL=0
for R in */skills/*/evidence/README.md; do
  [ -f "$R" ] || continue
  SKILL="${R%/evidence/README.md}"
  NOW="$(skill_hash "$SKILL")"
  # The header row nearest above the hash row names the batches.
  ROWS="$(awk '/^\| Item \|/ { h = $0 } /^\| Skill hash \|/ { print h; print; exit }' "$R")"
  if [ -z "$ROWS" ]; then
    echo "NO HASH: $R has no '| Skill hash |' row"; FAIL=1; continue
  fi
  HEAD="$(printf '%s\n' "$ROWS" | sed -n 1p)"; HASHES="$(printf '%s\n' "$ROWS" | sed -n 2p)"
  echo "${SKILL##*/} (skill now $NOW)"
  i=3
  while :; do
    LABEL="$(printf '%s' "$HEAD" | awk -F'|' -v i="$i" '{ gsub(/^ +| +$/, "", $i); print $i }')"
    CELL="$(printf '%s' "$HASHES" | awk -F'|' -v i="$i" '{ gsub(/^ +| +$/, "", $i); print $i }')"
    [ -n "$CELL" ] || break
    H="$(printf '%s' "$CELL" | grep -oE '`[0-9a-f]{12}`' | head -1 | tr -d '`')"
    [ -n "$H" ] || { echo "    NO HASH  $LABEL: the cell holds no backticked 12-character hash"; FAIL=1; i=$((i + 1)); continue; }
    [ "$LABEL" = "Value" ] && LABEL="every case"
    if [ "$H" = "$NOW" ]; then echo "    current  $LABEL"
    else echo "    STALE    $LABEL ran on $H"; fi
    i=$((i + 1))
  done
done
exit "$FAIL"
