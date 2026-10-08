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

# A relative --lint path belongs to the caller's cwd; resolve it before the cd
# below moves us to the repo root.
if [ "${1:-}" = "--lint" ] && [ -n "${2:-}" ]; then
  case "$2" in
    /*) ;;
    *) set -- "$1" "$PWD/$2" ;;
  esac
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$ROOT" ] || { echo "ABORT: not a git repository."; exit 1; }
cd "$ROOT" || { echo "ABORT: cannot enter repository root: $ROOT"; exit 1; }

TYPES='feat|fix|refactor|docs|test|chore|build|ci|perf|style'

# Repo-owned commit-message enforcers. The type(scope) format is this skill's
# stance, a default for repos that have none; when the repo enforces its own
# format, that format wins and the lint skips the stance checks. The other
# checks (length, blank line, provenance, body shape) are walls that no
# format conflicts with, so they always run.
find_enforcers() {
  local hooks f t
  hooks="$(git rev-parse --git-path hooks 2>/dev/null)"
  [ -n "$hooks" ] && [ -x "$hooks/commit-msg" ] && echo "$hooks/commit-msg"
  [ -f .husky/commit-msg ] && echo ".husky/commit-msg"
  for f in commitlint.config.js commitlint.config.cjs commitlint.config.mjs commitlint.config.ts \
           .commitlintrc .commitlintrc.json .commitlintrc.yml .commitlintrc.yaml \
           .commitlintrc.js .commitlintrc.cjs .commitlintrc.ts .gitlint; do
    [ -f "$f" ] && echo "$f"
  done
  [ -f package.json ] && grep -q '"commitlint"' package.json && echo "package.json (commitlint)"
  for f in lefthook.yml lefthook.yaml .lefthook.yml .lefthook.yaml; do
    [ -f "$f" ] && grep -q 'commit-msg' "$f" && echo "$f (commit-msg)"
  done
  for f in .pre-commit-config.yaml .pre-commit-config.yml; do
    [ -f "$f" ] && grep -qE 'commit-msg|conventional-pre-commit|commitizen|commitlint|gitlint' "$f" && echo "$f (commit-msg)"
  done
  t="$(git config --get commit.template 2>/dev/null)"
  [ -n "$t" ] && echo "commit.template=$t"
  return 0
}

if [ "${1:-}" = "--lint" ]; then
  MSG="${2:?usage: commit-preflight.sh --lint <message-file>}"
  [ -f "$MSG" ] || { echo "lint: no such file: $MSG"; exit 1; }
  FAIL=0
  err() { echo "LINT FAIL: $1"; FAIL=1; }
  SUBJ="$(head -1 "$MSG")"

  ENFORCER="$(find_enforcers | head -1)"
  if [ -n "$ENFORCER" ]; then
    echo "lint: repo enforces its own subject format ($ENFORCER) — type(scope) checks skipped; match the repo's recent subjects"
  else
    echo "$SUBJ" | grep -qE "^($TYPES)(\([a-z0-9-]+\))?: .+" \
      || err "subject must match 'type(scope): description' with type in: $TYPES"
    DESC="$(echo "$SUBJ" | sed -E "s/^($TYPES)(\([a-z0-9-]+\))?: //")"
    echo "$DESC" | grep -q '[][(){}]' && err "description contains parentheses/brackets (allowed only in the type(scope): prefix)"
    LC_ALL=C grep -qn '[^ -~]' <(echo "$SUBJ") && err "subject contains non-ASCII characters (no emojis)"
  fi
  [ "${#SUBJ}" -le 72 ] || err "subject is ${#SUBJ} chars (max 72)"
  # Provenance greps run on a copy with inline code spans blanked out, so a
  # message that legitimately QUOTES an attribution string in backticks (e.g. a
  # commit about this very lint) does not trip the wall. sed is line-preserving,
  # so reported line numbers still point into the real message.
  PROV_STRIP="$(mktemp)"
  sed 's/`[^`]*`//g' "$MSG" > "$PROV_STRIP"
  PROV_FILE="$PROV_STRIP"; PROV_WHAT="commit message"
  # --- provenance wall (identical block in git-create-pr/scripts/pr-preflight.sh)
  # Carries the change, never who or what composed it. A bare tool name stays
  # legal so work about an agent integration can describe itself; what fails is
  # attribution SHAPE — a byline, an authorship trailer, a session link, the
  # robot emoji. Regex catches the known spellings; the skill's own read-through
  # catches the phrasings no list can enumerate.
  # A byline names its tool within a few words of the verb, as a whole word —
  # so "built using cursor-based paging" and "produced by declined requests"
  # are prose, while "written with the help of Claude" is attribution.
  AGENTS='claude|anthropic|copilot|chatgpt|openai|gpt-[0-9][[:alnum:].]*|gemini|cursor|codeium|windsurf|devin|aider|cline|sourcegraph|cody|ai (assistant|agent|pair)s?|coding agents?|language models?|llms?'
  BYLINE='(generated|created|authored|written|composed|produced|made|built|drafted) (with|by|using)'
  NAMED="$BYLINE[[:space:]]+([^[:space:]]+[[:space:]]+){0,3}[^[:alnum:][:space:]]*($AGENTS)([^[:alnum:]_-]|\$)"

  HIT="$(grep -niE "^[[:space:]]*(co-authored-by|authored-by|assisted-by|generated-by):" "$PROV_FILE" | head -1)"
  [ -n "$HIT" ] && err "authorship trailer in the $PROV_WHAT: $HIT"

  HIT="$(grep -niE -- "$BYLINE" "$PROV_FILE" | grep -iE -- "$NAMED|https?://" | head -1)"
  [ -n "$HIT" ] && err "attribution byline in the $PROV_WHAT: $HIT"

  HIT="$(grep -niE 'claude\.ai|claude\.com/claude-code|chatgpt\.com|chat\.openai\.com|cursor\.com|copilot-workspace|githubcopilot' "$PROV_FILE" | head -1)"
  [ -n "$HIT" ] && err "link to an agent or session in the $PROV_WHAT: $HIT"

  HIT="$(grep -n '🤖' "$PROV_FILE" | head -1)"
  [ -n "$HIT" ] && err "agent marker emoji in the $PROV_WHAT: $HIT"
  # --- end provenance wall ---
  rm -f "$PROV_STRIP"

  if [ "$(wc -l < "$MSG")" -gt 1 ]; then
    [ -z "$(sed -n '2p' "$MSG")" ] || err "line 2 must be blank between subject and body"
    BULLETS="$(grep -c '^- ' "$MSG" || true)"
    [ "$BULLETS" -le 8 ] || err "body has $BULLETS bullets (hard cap 8 — summarize at a higher level)"
    grep -n '^- ' "$MSG" | awk -F: 'length($0)-length($1)-1 > 78 {print "LINT WARN: bullet on line " $1 " exceeds ~72 chars — trim it"}'
    grep -vE '^(- |$)' "$MSG" | tail -n +2 | grep -q . \
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
MODE="$([ -n "$STAGED" ] && echo 'SINGLE (staged changes exist — commit exactly those)' || echo 'GROUPED (nothing staged — split unstaged into logical commits)')"
ENFORCERS="$(find_enforcers)"
enforcer_line() {
  if [ -n "$ENFORCERS" ]; then
    echo "subject format: REPO-ENFORCED ($(printf '%s' "$ENFORCERS" | tr '\n' ',' | sed 's/,$//; s/,/, /g')) — write subjects in the repo's shape; the lint skips its type(scope) checks"
  else
    echo "subject format: type(scope): description (skill default — no repo enforcer found)"
  fi
}

TOTAL="$(git diff HEAD --shortstat 2>/dev/null | grep -oE '[0-9]+ insertion|[0-9]+ deletion' | awk '{s+=$1} END {print s+0}')"
NPATHS="$({ [ -n "$STAGED" ] && echo "$STAGED"; [ -n "$UNSTAGED" ] && echo "$UNSTAGED"; [ -n "$UNTRACKED" ] && echo "$UNTRACKED"; } | sort -u | grep -c .)"

# A one-file, small change needs none of the sectioned report — the fixed cost
# of the full layout would exceed the two git commands it replaces.
if [ "$NPATHS" -le 1 ] && [ "$TOTAL" -le 50 ]; then
  echo "mode: $MODE"
  enforcer_line
  echo "-- recent subjects (match scope naming and tone) --"
  git log --oneline -3 | sed 's/^/    /'
  echo "-- change --"
  if   [ -n "$STAGED" ];   then git diff --cached --stat | sed 's/^/    /'
  elif [ -n "$UNSTAGED" ]; then git diff --stat | sed 's/^/    /'
  else echo "$UNTRACKED" | sed 's/^/    (untracked) /'
  fi
  echo "== END PREFLIGHT (compact) — read the diff, lint the message with --lint, commit =="
  exit 0
fi

echo "mode: $MODE"
enforcer_line
echo
echo "-- recent subjects (match scope naming and tone) --"
git log --oneline -5 | sed 's/^/    /'
echo
echo "-- staged --";   [ -n "$STAGED" ]   && git diff --cached --stat | sed 's/^/    /' || echo "    (none)"
echo "-- unstaged --"; [ -n "$UNSTAGED" ] && git diff --stat | sed 's/^/    /'          || echo "    (none)"
echo "-- untracked --"; [ -n "$UNTRACKED" ] && echo "$UNTRACKED" | sed 's/^/    /'      || echo "    (none)"

echo
echo "total changed lines vs HEAD: $TOTAL$([ "$TOTAL" -gt 500 ] && echo '  (>500 — read the diff in batches by path, not all at once)')"

# Informational only, and only when the change spans paths — a printed
# suggestion anchors, and a feature spanning dirs is still one commit.
# (Not named GROUPS: that is a readonly bash builtin that swallows assignment.)
SPREAD="$({ [ -n "$UNSTAGED" ] && echo "$UNSTAGED"; [ -n "$UNTRACKED" ] && echo "$UNTRACKED"; } \
  | awk -F/ 'NF>1 {print $1"/"$2} NF<=1 {print $1}' | sort | uniq -c | sort -rn)"
if [ "$(printf '%s\n' "$SPREAD" | grep -c .)" -gt 1 ]; then
  echo
  echo "-- file spread (by top-level path; informational — group by intent, not path) --"
  printf '%s\n' "$SPREAD" | sed 's/^/    /'
fi
echo
echo "== END PREFLIGHT — analyze diffs, group, then lint each message with --lint before committing =="
