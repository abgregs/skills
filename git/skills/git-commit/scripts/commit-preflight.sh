#!/usr/bin/env bash
# commit-preflight.sh — deterministic detector for the /git-commit skill.
# Two modes:
#   commit-preflight.sh                 preflight report (state, conflicts,
#                                       staged/unstaged, log, stats, suggested
#                                       groupings by top-level dir)
#   commit-preflight.sh --lint <file>   lint a commit message written to a
#                                       file; exit 0 = OK, 1 = violations
# The model judges grouping and message content; this script owns everything
# regex-checkable. No `set -e` — a zero-match grep must not abort the report.
set -u

cd "$(git rev-parse --show-toplevel)" || exit 1

TYPES='feat|fix|refactor|docs|test|chore|build|ci|perf|style'

if [ "${1:-}" = "--lint" ]; then
  MSG="${2:?usage: commit-preflight.sh --lint <message-file>}"
  [ -f "$MSG" ] || { echo "lint: no such file: $MSG"; exit 1; }
  FAIL=0
  err() { echo "LINT FAIL: $1"; FAIL=1; }
  SUBJ="$(head -1 "$MSG")"

  echo "$SUBJ" | grep -qE "^($TYPES)(\([a-z0-9-]+\))?: .+" \
    || err "subject must match 'type(scope): description' with type in: $TYPES"
  [ "${#SUBJ}" -le 72 ] || err "subject is ${#SUBJ} chars (max 72)"
  DESC="$(echo "$SUBJ" | sed -E "s/^($TYPES)(\([a-z0-9-]+\))?: //")"
  echo "$DESC" | grep -q '[][(){}]' && err "description contains parentheses/brackets (allowed only in the type(scope): prefix)"
  LC_ALL=C grep -qn '[^ -~]' <(echo "$SUBJ") && err "subject contains non-ASCII characters (no emojis)"
  grep -ni 'claude' "$MSG" | grep -vi '^[0-9]*:co-authored-by:' | grep -q . \
    && err "message references Claude outside a Co-Authored-By trailer"

  if [ "$(wc -l < "$MSG")" -gt 1 ]; then
    [ -z "$(sed -n '2p' "$MSG")" ] || err "line 2 must be blank between subject and body"
    BULLETS="$(grep -c '^- ' "$MSG" || true)"
    [ "$BULLETS" -le 8 ] || err "body has $BULLETS bullets (hard cap 8 — summarize at a higher level)"
    grep -n '^- ' "$MSG" | awk -F: 'length($0)-length($1)-1 > 78 {print "LINT WARN: bullet on line " $1 " exceeds ~72 chars — trim it"}'
    grep -vE '^(- |$)' "$MSG" | tail -n +2 | grep -v '^Co-Authored-By:' | grep -q . \
      && echo "LINT WARN: body has non-bullet, non-trailer lines — body should be dash bullets"
  fi

  [ "$FAIL" = 0 ] && echo "lint: message OK"
  exit "$FAIL"
fi

# ---- preflight report
echo "== COMMIT PREFLIGHT =="
STATUS="$(git status --porcelain)"
if [ -z "$STATUS" ]; then
  echo "NOTHING TO COMMIT — working tree is clean. Stop."
  exit 0
fi
CONFLICTS="$(echo "$STATUS" | grep -E '^(UU|AA|DD|AU|UA|DU|UD)' || true)"
if [ -n "$CONFLICTS" ]; then
  echo "UNRESOLVED CONFLICTS — resolve before committing. Stop."
  echo "$CONFLICTS" | sed 's/^/    /'
  exit 1
fi

STAGED="$(git diff --cached --name-only)"
UNSTAGED="$(git diff --name-only)"
UNTRACKED="$(echo "$STATUS" | grep '^??' | awk '{print $2}' || true)"

echo "mode: $([ -n "$STAGED" ] && echo 'SINGLE (staged changes exist — commit exactly those)' || echo 'GROUPED (nothing staged — split unstaged into logical commits)')"
echo
echo "-- recent subjects (match scope naming and tone) --"
git log --oneline -5 | sed 's/^/    /'
echo
echo "-- staged --";   [ -n "$STAGED" ]   && git diff --cached --stat | sed 's/^/    /' || echo "    (none)"
echo "-- unstaged --"; [ -n "$UNSTAGED" ] && git diff --stat | sed 's/^/    /'          || echo "    (none)"
echo "-- untracked --"; [ -n "$UNTRACKED" ] && echo "$UNTRACKED" | sed 's/^/    /'      || echo "    (none)"

TOTAL="$(git diff HEAD --shortstat 2>/dev/null | grep -oE '[0-9]+ insertion|[0-9]+ deletion' | awk '{s+=$1} END {print s+0}')"
echo
echo "total changed lines vs HEAD: $TOTAL$([ "$TOTAL" -gt 500 ] && echo '  (>500 — read the diff in batches by path, not all at once)')"

echo
echo "-- suggested groupings (by top-level path — a starting point, the model judges the final grouping) --"
{ [ -n "$UNSTAGED" ] && echo "$UNSTAGED"; [ -n "$UNTRACKED" ] && echo "$UNTRACKED"; } \
  | awk -F/ 'NF>1 {print $1"/"$2} NF<=1 {print $1}' | sort | uniq -c | sort -rn | sed 's/^/    /'
echo
echo "== END PREFLIGHT — analyze diffs, group, then lint each message with --lint before committing =="
