#!/usr/bin/env bash
# check-shared-blocks.sh — repo tooling, not part of any skill.
#
# Some logic has to exist verbatim in two skills. Skills install as independent
# folders (the CLI hashes one skill folder and copies it alone), so a shared
# file outside a skill folder would live in this repo and never reach an
# install. Duplication is the only option that survives `npx skills add
# abgregs/skills@<one-skill>` — this guard is what keeps the copies honest.
#
# A shared block is delimited in each file by:
#     # --- <name> (identical block in <other path> ...
#     ... body ...
#     # --- end <name> ---
#
# Usage: bash scripts/check-shared-blocks.sh   (exit 1 on drift)
set -u

cd "$(git rev-parse --show-toplevel)" || exit 1
FAIL=0

# block name -> the files that must carry it, space separated
BLOCKS="provenance wall:git/skills/git-commit/scripts/commit-preflight.sh git/skills/git-create-pr/scripts/pr-preflight.sh"

extract() { # extract <file> <name> — the block body, comments and all
  awk -v n="$2" '
    index($0, "# --- " n)      && !seen { inb = 1; seen = 1; next }
    index($0, "# --- end " n)  && inb   { inb = 0; next }
    inb { print }
  ' "$1"
}

# Process substitution, not a pipe — a pipe would run the loop in a subshell
# and FAIL would never reach the exit below.
while IFS=: read -r NAME FILES; do
  set -- $FILES
  REF="$1"; shift
  REF_BODY="$(extract "$REF" "$NAME")"
  if [ -z "$REF_BODY" ]; then
    echo "DRIFT: block '$NAME' not found in $REF"; FAIL=1; continue
  fi
  for F in "$@"; do
    if [ "$(extract "$F" "$NAME")" = "$REF_BODY" ]; then
      echo "ok: '$NAME' matches between $REF and $F"
    else
      echo "DRIFT: block '$NAME' differs between $REF and $F"
      diff <(echo "$REF_BODY") <(extract "$F" "$NAME") | sed 's/^/    /'
      FAIL=1
    fi
  done
done < <(echo "$BLOCKS")

exit "$FAIL"
