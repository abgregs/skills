#!/usr/bin/env bash
# commit-preflight.sh — deterministic detector for the /git-commit skill.
# Two modes:
#   commit-preflight.sh                 preflight report (state, conflicts,
#                                       staged/unstaged, log, stats, suggested
#                                       groupings by top-level dir)
#   commit-preflight.sh --amend         amend report: the subject facts, the
#                                       last commit, staged and unstaged, and
#                                       whether the commit is already pushed;
#                                       no clean-tree stop
#   commit-preflight.sh --lint <file>   lint a commit message written to a
#                                       file; exit 0 = OK, 1 = violations
#   commit-preflight.sh --commit <file> [--accept-warnings] [--amend [--message-only]] [-- <path>...]
#                                       lint, then commit only on a clean
#                                       result: exactly the named paths, or
#                                       the index when none are named, or
#                                       amend the last commit with the index
#                                       (its message only with --message-only);
#                                       nothing is committed on a stop, and its
#                                       NOT COMMITTED line names the cause:
#                                       exit 1 = the gate stopped before git ran,
#                                       2 = the lint warned, 3 = the pre-commit
#                                       hook failed, 4 = the commit-msg hook
#                                       rejected the message, 5 = git itself or
#                                       another hook refused; a stop that
#                                       repeats the last one says to hand back
#   commit-preflight.sh --size <path>...
#                                       changed lines a reviewer reads in a
#                                       proposed commit, lockfiles excluded
# The model judges grouping and message content; this script owns everything
# regex-checkable. No `set -e` — a zero-match grep must not abort the report.
set -u

# A relative message path belongs to the caller's cwd; resolve it, and this
# script's own path, before the cd below moves us to the repo root.
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
CALLER="$PWD"
case "${1:-}" in
  --lint|--commit)
    case "${2:-}" in
      ""|/*) ;;
      *) MODE="$1"; M="$PWD/$2"; shift 2; set -- "$MODE" "$M" "$@" ;;
    esac ;;
esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$ROOT" ] || { echo "ABORT: not a git repository."; exit 1; }
cd "$ROOT" || { echo "ABORT: cannot enter repository root: $ROOT"; exit 1; }

TYPES='feat|fix|refactor|docs|test|chore|build|ci|perf|style'

# Repo-owned commit-message enforcers. The type(scope) format is this skill's
# stance, a default for repos that have none; when the repo enforces its own
# format, that format wins and the lint skips the checks that read the
# type(scope): prefix (its shape, brackets in the description, the types that
# take no Why:). ASCII yields to the repo's history instead (see
# nonascii_subjects). The other checks (length, blank line, provenance, body
# shape) are walls that no format conflicts with, so they always run.
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

# How many of the repo's last 20 subjects use characters outside printable
# ASCII, such as a gitmoji repo's emoji. The ASCII rule yields to this history
# rather than to an enforcer: commitlint's standard config never checks emoji,
# so a config alone says nothing about whether the repo wants them.
nonascii_subjects() { git log -n 20 --format=%s 2>/dev/null | LC_ALL=C grep -c '[^ -~]'; }

# The ticket key the branch name carries, such as WID-12 in feature/WID-12-login:
# capitals and digits, a hyphen, a number. Encodings and standards that share
# the shape (UTF-8, SHA-256) are not tickets. A bare issue number is left to
# the skill's judgment, since branch names hold numbers for other reasons.
ticket_key() {
  git symbolic-ref --short -q HEAD 2>/dev/null | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' \
    | grep -vE '^(UTF|UCS|ISO|SHA|MD|TLS|SSL|HTTP)-' | head -1
}

# The facts every subject is held to, for both reports: the format the lint
# applies, the characters the repo's history allows, and the branch's ticket key.
subject_facts() {
  local enforcers n key
  enforcers="$(find_enforcers)"
  if [ -n "$enforcers" ]; then
    echo "subject format: REPO-ENFORCED ($(printf '%s' "$enforcers" | tr '\n' ',' | sed 's/,$//; s/,/, /g')) — write subjects in the repo's shape; the lint skips its type(scope) checks"
  else
    echo "subject format: type(scope): description (skill default — no repo enforcer found)"
  fi
  n="$(nonascii_subjects)"
  if [ "${n:-0}" -gt 0 ]; then
    echo "subject characters: $n of the last 20 subjects use non-ASCII, such as emoji — the lint allows it, as the repo does"
  else
    echo "subject characters: ASCII only — no recent subject uses anything else"
  fi
  key="$(ticket_key)"
  if [ -n "$key" ]; then
    echo "ticket key: $key, from the branch name — every subject carries it, and the lint warns when one does not"
  else
    echo "ticket key: none in the branch name — look for one in the recent subjects or the contributing notes"
  fi
}

if [ "${1:-}" = "--lint" ]; then
  MSG="${2:?usage: commit-preflight.sh --lint <message-file>}"
  [ -f "$MSG" ] || { echo "lint: no such file: $MSG"; exit 1; }
  FAIL=0
  err() { echo "LINT FAIL: $1"; FAIL=1; }
  warn() { echo "LINT WARN: $1"; }
  SUBJ="$(head -1 "$MSG")"

  ENFORCER="$(find_enforcers | head -1)"
  if [ -n "$ENFORCER" ]; then
    echo "lint: repo enforces its own subject format ($ENFORCER) — the type(scope), bracket, and no-Why: type checks are skipped; match the repo's recent subjects"
  else
    echo "$SUBJ" | grep -qE "^($TYPES)(\([a-z0-9-]+\))?: .+" \
      || err "subject must match 'type(scope): description' with type in: $TYPES"
    DESC="$(echo "$SUBJ" | sed -E "s/^($TYPES)(\([a-z0-9-]+\))?: //")"
    echo "$DESC" | grep -q '[][(){}]' && err "description contains parentheses/brackets (allowed only in the type(scope): prefix)"
    # These types state their own reason; a Why: bullet on one is padding.
    TYPE="$(echo "$SUBJ" | sed -nE "s/^($TYPES)(\([a-z0-9-]+\))?: .*/\1/p")"
    case "$TYPE" in
      docs|chore|test) grep -qE '^- Why:' "$MSG" && err "a $TYPE commit takes no Why: bullet — remove it" ;;
    esac
  fi
  NONASCII="$(nonascii_subjects)"
  if [ "${NONASCII:-0}" -gt 0 ]; then
    echo "lint: $NONASCII of the repo's last 20 subjects use non-ASCII characters — the ASCII check is skipped"
  else
    LC_ALL=C grep -q '[^ -~]' <(echo "$SUBJ") && err "subject contains non-ASCII characters (no emojis); the repo's recent subjects use none"
  fi
  # Why:, when present, is the single first bullet.
  WHYS="$(grep -c '^- Why:' "$MSG" || true)"
  [ "$WHYS" -le 1 ] || err "message has $WHYS Why: bullets (at most one)"
  [ "$WHYS" = 0 ] || [ "$(grep -m1 '^- ' "$MSG" | cut -c1-6)" = "- Why:" ] || err "the Why: bullet must be the first bullet"
  [ "${#SUBJ}" -le 72 ] || err "subject is ${#SUBJ} chars (max 72)"
  KEY="$(ticket_key)"
  [ -n "$KEY" ] && ! printf '%s\n' "$SUBJ" | grep -qF "$KEY" \
    && warn "subject lacks the ticket key $KEY from the branch name — place it where the recent subjects do, else as the subject's last word"
  # Provenance greps run on a copy with inline code spans blanked out, so a
  # message that legitimately QUOTES an attribution string in backticks (e.g. a
  # commit about this very lint) does not trip the wall. sed is line-preserving,
  # so reported line numbers still point into the real message.
  PROV_STRIP="$(mktemp)"
  sed 's/`[^`]*`//g' "$MSG" > "$PROV_STRIP"
  PROV_FILE="$PROV_STRIP"; PROV_WHAT="commit message"; PROV_ORIG="$MSG"
  # --- provenance wall (identical block in git-create-pr/scripts/pr-preflight.sh)
  # needs from the caller: PROV_FILE (prose to check), PROV_WHAT (its name in messages), err()
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
  # --- clarity warnings (identical block in git-create-pr/scripts/pr-preflight.sh)
  # needs from the caller: PROV_FILE, PROV_WHAT, PROV_ORIG (the unstripped file, for quoting), warn()
  # The slice of Simplified Technical English that fits prose quoting
  # identifiers: no gerund bullets, no hedging verbs, no vague openers. Warnings,
  # not failures — each has a legitimate exception ("May 2026", a noun that ends
  # in -ing) that the skill's read-through can judge. Matched on the
  # code-stripped copy, reported from the original so the line reads whole.
  BULLET='[[:space:]]*- (\[[ xX]\] )?'
  orig_line() { echo "$1:$(sed -n "${1}p" "$PROV_ORIG")"; }
  HIT="$(grep -nE "^${BULLET}[A-Za-z]+ing([^[:alnum:]]|\$)" "$PROV_FILE" \
        | grep -viE "^[0-9]+:${BULLET}(bring|string|during|thing|nothing|something|anything|everything|ring|sing|king|wing|swing|spring)([^[:alnum:]]|\$)" | head -1)"
  [ -n "$HIT" ] && warn "bullet opens with an -ing word — write the action or the result: $(orig_line "${HIT%%:*}")"
  HIT="$(grep -niE '(^|[^[:alnum:]])(should|would|may|might|probably|hopefully|possibly)([^[:alnum:]]|$)' "$PROV_FILE" | head -1)"
  [ -n "$HIT" ] && warn "hedge word in the $PROV_WHAT — state what the code does, or name the risk outright: $(orig_line "${HIT%%:*}")"
  HIT="$(grep -niE "^${BULLET}(improves?|cleans? ?up|cleanup|tweaks?|polish(es)?|enhances?|various|some|misc|miscellaneous|minor)([^[:alnum:]]|\$)" "$PROV_FILE" | head -1)"
  [ -n "$HIT" ] && warn "vague opener in a bullet — name what changed: $(orig_line "${HIT%%:*}")"
  # --- end clarity warnings ---
  # Code as subject, for commit messages only: a PR body is prose, so this
  # stays out of the block shared with pr-preflight.sh. Every bullet but Why:
  # names the code that acts, so a bullet that opens with a command verb
  # ("Add `test_x`") or uses a passive verb ("`reset` is removed") breaks the
  # form. Why: and its wrapped lines are skipped: the world before the change
  # may hold no code to make the subject. Warnings, not failures, since a noun
  # can read as a verb. The command verbs are the ones the skill's recorded
  # runs opened bullets with, and their kin; -en participles are listed, since
  # "open", "often", and "token" end the same way. A participle that names a
  # state ("is unchanged") is left alone.
  FORM="$(awk 'NR == 1 { next } /^- Why:/ { why = 1; next } /^- / { why = 0; print NR ":" $0; next }
              /^  [^ ]/ && !why { print NR ":" $0 }' "$PROV_FILE")"
  CMD='(add|remove|drop|rename|move|replace|update|extract|delete|introduce|convert|bump|wire|expose|document|list|make|use|fix|keep|skip|guard|ensure|allow|prevent|avoid|restore|revert|inline|simplify|change|cover|mark|pin|set|split)'
  for N in $(printf '%s\n' "$FORM" | grep -iE "^[0-9]+:- $CMD([^[:alnum:]]|\$)" | cut -d: -f1); do
    warn "bullet opens with a command verb — start it with the code that acts: a test covers, a new name replaces, an owner drops: $(orig_line "$N")"
  done
  BE='(is|are|was|were|be|been|being|get|gets|got)[[:space:]]+((now|no longer|also|only|then|still|always|never|not)[[:space:]]+)?'
  PART='([a-z]{2,}ed|set|put|read|built|made|sent|kept|left|held|run|hit|cut|split|bound|found|done|seen|shown|known|drawn|thrown|grown|given|taken|written|hidden|broken|chosen|driven|proven|frozen|forgotten)'
  for N in $(printf '%s\n' "$FORM" | grep -iE "(^|[^[:alnum:]])$BE$PART([^[:alnum:]]|\$)" \
             | grep -viE "(^|[^[:alnum:]])$BE(un[a-z]+ed|indeed)([^[:alnum:]]|\$)" | cut -d: -f1); do
    warn "passive verb — make the code that acts the subject, as in: Session sets isRecording: $(orig_line "$N")"
  done
  rm -f "$PROV_STRIP"

  if [ "$(wc -l < "$MSG")" -gt 1 ]; then
    [ -z "$(sed -n '2p' "$MSG")" ] || err "line 2 must be blank between subject and body"
    BULLETS="$(grep -c '^- ' "$MSG" || true)"
    [ "$BULLETS" -le 6 ] || err "body has $BULLETS bullets (hard cap 6 — summarize at a higher level)"
    # A bullet too long for one line wraps onto lines indented two spaces.
    grep -nE '^(- |  [^ ])' "$MSG" | awk -F: 'length($0)-length($1)-1 > 100 {print "LINT WARN: line " $1 " exceeds ~100 chars — trim it, or wrap it onto a line indented two spaces"}'
    grep -vE '^(- |  [^ ]|$)' "$MSG" | tail -n +2 | grep -q . \
      && echo "LINT WARN: body has non-bullet lines — body should be dash bullets, wrapped lines indented two spaces"
  fi

  [ "$FAIL" = 0 ] && echo "lint: message OK"
  exit "$FAIL"
fi

# The only path to a commit: the lint result, not the model, decides whether
# git runs. A warning blocks until the line is fixed or explicitly accepted.
# Named paths are committed with `git commit -- <paths>`, which takes exactly
# those paths from the tree and nothing else, so a stopped commit leaves no
# staged files behind to leak into the next one. Paths resolve from the
# caller's directory, as git would resolve them there.
if [ "${1:-}" = "--commit" ]; then
  USAGE="usage: commit-preflight.sh --commit <message-file> [--accept-warnings] [--amend [--message-only]] [-- <path>...]"
  MSG="${2:?$USAGE}"; shift 2
  ACCEPT=0; AMEND=0; MSGONLY=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --accept-warnings) ACCEPT=1; shift ;;
      --amend) AMEND=1; shift ;;
      --message-only) MSGONLY=1; shift ;;
      --) shift; break ;;
      *) echo "$USAGE"; exit 1 ;;
    esac
  done
  if [ "$MSGONLY" = 1 ] && [ "$AMEND" = 0 ]; then
    echo "$USAGE"; exit 1
  fi
  # Every stop prints one NOT COMMITTED line: its cause, then its fix. A stop
  # that repeats the last stop on this message file made no progress, so its
  # fix becomes a hand-back to the user instead of another loop. The record
  # sits beside the message file and goes when the commit lands.
  STOPF="$MSG.stop"
  stop() { # <exit> <cause> <fix> [<what makes two stops the same; default the cause>]
    local same="${4:-$2}"
    if [ -f "$STOPF" ] && [ "$(cat "$STOPF")" = "$same" ]; then
      echo "NOT COMMITTED: $2 — the same stop as the last run on this message: hand back, showing the user $MSG and the output above"
    else
      echo "NOT COMMITTED: $2 — $3"
    fi
    printf '%s' "$same" > "$STOPF" 2>/dev/null
    exit "$1"
  }
  # An amend takes the index as the user confirmed it, and an empty index
  # rewords the message only, so it names no paths and needs nothing staged.
  [ "$AMEND" = 1 ] && [ $# -gt 0 ] && stop 1 "--amend takes the index, not paths" "stage the files to fold in"
  # A named path takes the whole file from the tree; with hunks staged by
  # hand, that would commit more than the user chose.
  [ $# -gt 0 ] && ! git diff --cached --quiet \
    && stop 1 "changes are staged" "commit the index without paths (single mode), or unstage them before naming paths"
  [ "$AMEND" = 0 ] && [ $# = 0 ] && git diff --cached --quiet \
    && stop 1 "nothing staged" "name this commit's paths after --"
  OUT="$(bash "$SELF" --lint "$MSG")"; RC=$?
  echo "$OUT"
  [ "$RC" != 0 ] && stop 1 "lint failed" "fix the message in $MSG and run --commit again" "$OUT"
  echo "$OUT" | grep -q '^LINT WARN' && [ "$ACCEPT" = 0 ] \
    && stop 2 "lint warned" "fix each warned line in $MSG and run --commit again; add --accept-warnings only when every warning misreads its line" "$OUT"
  # git runs with trace2 on, so a refusal can name the hook that caused it.
  # --only with no paths rewords the last commit and leaves anything staged
  # in place, so a message-only amend never folds in the user's index.
  T2="$(mktemp "${TMPDIR:-/tmp}/commit-trace.XXXXXX")"
  if [ "$MSGONLY" = 1 ]; then
    GIT_TRACE2_PERF="$T2" git commit --amend --only -F "$MSG"
  elif [ "$AMEND" = 1 ]; then
    GIT_TRACE2_PERF="$T2" git commit --amend -F "$MSG"
  elif [ $# -gt 0 ]; then
    GIT_TRACE2_PERF="$T2" git -C "$CALLER" commit -F "$MSG" -- "$@"
  else
    GIT_TRACE2_PERF="$T2" git commit -F "$MSG"
  fi
  RC=$?
  if [ "$RC" = 0 ]; then rm -f "$STOPF" "$T2"; exit 0; fi
  # git ran and refused. The hook that failed, if one did, is the top-level
  # process's (depth d0) child of class hook with a nonzero exit code; git
  # commands a hook runs itself trace at depth d1 and are left out. A git too
  # old for trace2 names no hook, and the stop falls to exit 5.
  HOOK="$(awk -F'|' '
    $2 ~ /^ *d0 *$/ && $4 ~ /child_start/ && match($NF, /\[ch[0-9]+\] class:hook hook:[A-Za-z_-]+/) {
      s = substr($NF, RSTART, RLENGTH); id = s; sub(/^\[ch/, "", id); sub(/\].*/, "", id)
      name = s; sub(/.*hook:/, "", name); hook[id] = name }
    $2 ~ /^ *d0 *$/ && $4 ~ /child_exit/ && match($NF, /\[ch[0-9]+\] pid:-?[0-9]+ code:-?[0-9]+/) {
      s = substr($NF, RSTART, RLENGTH); id = s; sub(/^\[ch/, "", id); sub(/\].*/, "", id)
      code = s; sub(/.*code:/, "", code)
      if ((id in hook) && code != 0) failed = hook[id] }
    END { print failed }' "$T2" 2>/dev/null)"
  rm -f "$T2"
  case "$HOOK" in
    pre-commit) stop 3 "the pre-commit hook failed, output above" "fix what it flags and run --commit again" ;;
    commit-msg) stop 4 "the commit-msg hook rejected the message, output above" "rewrite the subject to the rule it enforces and run --commit again" ;;
    "") stop 5 "git refused the commit (exit $RC), output above" "nothing in the message or the files fixes this: show the user the output" ;;
    *) stop 5 "the $HOOK hook failed, output above" "the skill has no rule for this hook: show the user the output" ;;
  esac
fi

# Amend report: the facts an amend's message is held to, without the
# clean-tree stop, since a message-only amend starts from a clean tree.
if [ "${1:-}" = "--amend" ]; then
  echo "== AMEND PREFLIGHT =="
  CONFLICTS="$(git status --porcelain | grep -E '^(UU|AA|DD|AU|UA|DU|UD)' || true)"
  if [ -n "$CONFLICTS" ]; then
    echo "UNRESOLVED CONFLICTS — resolve before amending. Stop."
    echo "$CONFLICTS" | sed 's/^/    /'
    exit 1
  fi
  git rev-parse -q --verify HEAD >/dev/null || { echo "NO COMMIT TO AMEND — the branch has no commits yet. Stop."; exit 1; }
  subject_facts
  echo "-- last commit (the one the amend rewrites) --"
  git log -1 --format='%h %s%n%b' | sed '/^[[:space:]]*$/d; s/^/    /'
  echo "-- staged (folds in only when the user amends with staged changes) --"
  if git diff --cached --quiet; then echo "    (none)"; else git diff --cached --stat | sed 's/^/    /'; fi
  echo "-- unstaged (stays out of the amend) --"
  if git diff --quiet; then echo "    (none)"; else git diff --stat | sed 's/^/    /'; fi
  echo "-- recent subjects (match scope naming and tone) --"
  git log --oneline -5 | sed 's/^/    /'
  UP="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
  if [ -z "$UP" ]; then
    echo "remote: no upstream — the amend stays local"
  elif git merge-base --is-ancestor HEAD "$UP" 2>/dev/null; then
    echo "remote: the last commit is already on $UP — updating it after the amend takes a force-push"
  else
    echo "remote: the last commit is not on $UP yet — pushing the amend needs no force"
  fi
  echo "== END AMEND PREFLIGHT =="
  exit 0
fi

# Review size of a proposed commit, for the close calls in grouping: the
# changed lines a reviewer reads, from the caller's directory like git.
# Lockfiles and binaries are left out, since no one reads them line by line.
if [ "${1:-}" = "--size" ]; then
  shift
  [ $# -gt 0 ] || { echo "usage: commit-preflight.sh --size <path>..."; exit 1; }
  LOCKS='(^|/)(package-lock\.json|npm-shrinkwrap\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lockb?|Cargo\.lock|Gemfile\.lock|composer\.lock|poetry\.lock|uv\.lock|Pipfile\.lock|go\.sum|Package\.resolved|flake\.lock|mix\.lock|pubspec\.lock)$'
  git -C "$CALLER" diff --numstat HEAD -- "$@" | LOCKS="$LOCKS" awk -F'\t' '
    $1 == "-" || $3 ~ ENVIRON["LOCKS"] { skipped++; next }
    { lines += $1 + $2; files++ }
    END {
      printf "review size: %d changed lines in %d files", lines, files
      if (skipped) printf " (%d lockfile or binary files left out)", skipped
      print "; about 400 changed lines is an hour of review"
    }'
  exit 0
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
TOTAL="$(git diff HEAD --shortstat 2>/dev/null | grep -oE '[0-9]+ insertion|[0-9]+ deletion' | awk '{s+=$1} END {print s+0}')"
NPATHS="$({ [ -n "$STAGED" ] && echo "$STAGED"; [ -n "$UNSTAGED" ] && echo "$UNSTAGED"; [ -n "$UNTRACKED" ] && echo "$UNTRACKED"; } | sort -u | grep -c .)"

# A one-file, small change needs none of the sectioned report — the fixed cost
# of the full layout would exceed the two git commands it replaces.
if [ "$NPATHS" -le 1 ] && [ "$TOTAL" -le 50 ]; then
  echo "mode: $MODE"
  subject_facts
  echo "-- recent subjects (match scope naming and tone) --"
  git log --oneline -3 | sed 's/^/    /'
  echo "-- change --"
  if   [ -n "$STAGED" ];   then git diff --cached --stat | sed 's/^/    /'
  elif [ -n "$UNSTAGED" ]; then git diff --stat | sed 's/^/    /'
  else echo "$UNTRACKED" | sed 's/^/    (untracked) /'
  fi
  echo "== END PREFLIGHT (compact) — read the diff, commit through --commit =="
  exit 0
fi

echo "mode: $MODE"
subject_facts
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
echo "== END PREFLIGHT — analyze diffs, group, then commit each group through --commit -- <paths> =="
