#!/usr/bin/env bash
# pr-preflight.sh — deterministic detector for the /git-create-pr skill.
# Two modes:
#   pr-preflight.sh [base]                  preflight report (tooling, base,
#                                           push state, existing PR, repo
#                                           template, title style, diff) plus
#                                           the action to take
#   pr-preflight.sh --lint <body> [title]   lint a PR body written to a file,
#                                           and the title if given;
#                                           exit 0 = OK, 1 = violations
#
# The script does not touch the working tree, the index, or any local branch:
# the model writes the body and runs the two mutating commands, so hook and API
# output lands in its context. It DOES fetch — that writes remote-tracking refs
# and objects, which the base comparison depends on.
#
# It owns everything regex-checkable; the model owns what the PR says.
# No `set -e` — a zero-match grep must not abort the report.
set -u

# Read-only by default: no index refresh, and raw UTF-8 paths so the bucketer
# and the deleted-file list see real filenames rather than octal escapes.
git() { command git --no-optional-locks -c core.quotePath=false "$@"; }

# A relative --lint path belongs to the caller's cwd; resolve it before the cd
# below moves us to the repo root.
if [ "${1:-}" = "--lint" ] && [ -n "${2:-}" ]; then
  case "$2" in
    /*) ;;
    *) set -- "$1" "$PWD/$2" "${3:-}" ;;
  esac
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$ROOT" ] || { echo "ABORT: not a git repository."; exit 1; }
cd "$ROOT" || { echo "ABORT: cannot enter repository root: $ROOT"; exit 1; }

TYPES='feat|fix|refactor|docs|test|chore|build|ci|perf|style'

# The repo's own PR template outranks this skill's — the environment wins.
find_template() {
  for p in .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md \
           docs/pull_request_template.md docs/PULL_REQUEST_TEMPLATE.md \
           pull_request_template.md PULL_REQUEST_TEMPLATE.md; do
    [ -f "$p" ] && { echo "$p"; return; }
  done
}

# A PULL_REQUEST_TEMPLATE directory holds several templates and GitHub applies
# none of them without a ?template= choice, so report it instead of guessing.
template_dir() {
  for d in .github/PULL_REQUEST_TEMPLATE .github/pull_request_template \
           docs/PULL_REQUEST_TEMPLATE; do
    [ -d "$d" ] && { echo "$d"; return; }
  done
}

# What a reader of the rendered markdown sees: HTML comments and fenced blocks
# blanked (line count kept), trailing whitespace and CRs stripped. Templates
# and bodies both pass through it, so a heading inside `<!-- -->` or a fence is
# never demanded, and a CRLF body still matches line for line.
md_visible() {
  awk '
    /^[[:space:]]*(```|~~~)/ && !inc {
      t = $0; sub(/^[[:space:]]*/, "", t); t = substr(t, 1, 3)
      if (fence == "") fence = t; else if (t == fence) fence = ""
      print ""; next
    }
    fence != "" { print ""; next }
    {
      line = $0; out = ""
      while (line != "") {
        if (inc) {
          i = index(line, "-->")
          if (i) { line = substr(line, i + 3); inc = 0 } else line = ""
        } else {
          i = index(line, "<!--")
          if (i) { out = out substr(line, 1, i - 1); line = substr(line, i + 4); inc = 1 }
          else { out = out line; line = "" }
        }
      }
      print out
    }' "$1" | sed -E 's/[[:space:]]+$//'
}

# The lines a repo template makes mandatory: headings, bold labels, checklist
# items. Printing exactly these keeps the shape shown equal to the shape
# enforced, and keeps an essay of template prose out of the report.
template_shape() {
  md_visible "$1" | grep -E '^(#{1,6} |\*\*.+\*\*:?$|[[:space:]]*- \[[ xX]\] )'
}

# One line per piece of template shape missing from $BODY_VIS; NOREQ when the
# template has no shape to enforce. Headings match a whole line; a bold label is
# filled in on its own line (`**Ticket:** ENG-1`), so it matches as a prefix.
template_misses() {
  SHAPE="$(template_shape "$1")"
  [ -n "$SHAPE" ] || { echo NOREQ; return; }
  printf '%s\n' "$SHAPE" | while IFS= read -r S; do
    case "$S" in
      '#'*)  printf '%s\n' "$BODY_VIS" | grep -qxF -- "$S" || echo "section missing: $S" ;;
      '**'*) printf '%s\n' "$BODY_VIS" | grep -qF -- "$S" || echo "label missing: $S" ;;
      *)
        ITEM="$(printf '%s\n' "$S" | sed -nE 's/^[[:space:]]*- \[[ xX]\] //p')"
        [ -z "$ITEM" ] || printf '%s\n' "$BODY_VIS" | grep -qF -- "$ITEM" \
          || echo "checklist item missing: $ITEM" ;;
    esac
  done
}

# Title style is read off this repo's history, never assumed. One log call.
# Merge commits are skipped: their subjects are written by the forge, not the
# repo's convention.
title_style() {
  LOG="$(git log --no-merges --format=%s -30 2>/dev/null)"
  N="$(printf '%s\n' "$LOG" | grep -c .)"
  C="$(printf '%s\n' "$LOG" | grep -cE "^($TYPES)(\([a-z0-9._-]+\))?!?: ")"
  if [ "$N" -ge 5 ] && [ "$(( C * 2 ))" -ge "$N" ]; then
    echo conventional
  else
    echo plain
  fi
}

if [ "${1:-}" = "--lint" ]; then
  BODY="${2:?usage: pr-preflight.sh --lint <body-file> [title]}"
  TITLE="${3:-}"
  [ -f "$BODY" ] || { echo "lint: no such file: $BODY"; exit 1; }
  [ -s "$BODY" ] || { echo "LINT FAIL: body is empty"; exit 1; }
  FAIL=0
  err() { echo "LINT FAIL: $1"; FAIL=1; }

  # Prose only — fenced blocks and inline code spans blanked out. Checks that
  # look for template leftovers must not fire on the code a PR body
  # legitimately quotes (`arr[i]`, `[ -n "$x" ]`). Blanked, not deleted, so
  # line numbers in findings still point into the real body.
  # Fences close only on their own marker (``` or ~~~); an indented code block
  # is a 4-space/tab line after a blank or code line that is not a list item.
  PROSE="$(awk '
    BEGIN { prev = "blank" }
    /^[[:space:]]*(```|~~~)/ {
      t = $0; sub(/^[[:space:]]*/, "", t); t = substr(t, 1, 3)
      if (f == "") f = t; else if (t == f) f = ""
      print ""; prev = "text"; next
    }
    f != "" { print ""; next }
    /^(    |\t)/ && $0 !~ /^[[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]/ && (prev == "blank" || prev == "code") {
      print ""; prev = "code"; next
    }
    { print; prev = ($0 ~ /^[[:space:]]*$/) ? "blank" : "text" }' "$BODY" | sed 's/`[^`]*`//g')"

  BODY_VIS="$(md_visible "$BODY")"
  TPL="$(find_template)"; TPLDIR="$(template_dir)"
  if [ -n "$TPL" ]; then
    MISS="$(template_misses "$TPL")"
    if [ "$MISS" = NOREQ ]; then
      echo "LINT WARN: $TPL has no headings, labels, or checklist items — match its shape by hand"
    else
      while IFS= read -r M; do
        [ -z "$M" ] || err "repo template ($TPL) $M"
      done <<<"$MISS"
    fi
  elif [ -n "$TPLDIR" ]; then
    # Preflight told the model to pick one; judge the body against whichever
    # template it matches best (most shape lines present, then fewest missing),
    # and name that one in any failure.
    BEST=""; BEST_N=-1; BEST_HIT=-1; BEST_MISS=""
    for T in "$TPLDIR"/*; do
      [ -f "$T" ] || continue
      MISS="$(template_misses "$T")"
      [ "$MISS" = NOREQ ] && continue
      N="$(printf '%s' "$MISS" | grep -c .)"
      HIT=$(( $(template_shape "$T" | grep -c .) - N ))
      if [ "$BEST_N" -lt 0 ] || [ "$HIT" -gt "$BEST_HIT" ] \
         || { [ "$HIT" = "$BEST_HIT" ] && [ "$N" -lt "$BEST_N" ]; }; then
        BEST="$T"; BEST_N="$N"; BEST_HIT="$HIT"; BEST_MISS="$MISS"
      fi
    done
    if [ "$BEST_N" -lt 0 ]; then
      echo "LINT WARN: no template in $TPLDIR has headings, labels, or checklist items — match the chosen one by hand"
    else
      while IFS= read -r M; do
        [ -z "$M" ] || err "closest repo template ($BEST) $M"
      done <<<"$BEST_MISS"
    fi
  else
    for H in '## Summary' '## Changes' '## Testing'; do
      grep -qxF -- "$H" "$BODY" || err "missing required section: $H"
    done
    # Count inside the Testing section, and accept ticked boxes — a verified
    # checklist is the goal, not an unticked one.
    TESTING="$(awk '/^##[[:space:]]+Testing/ { f = 1; next } /^##[[:space:]]/ { f = 0 } f' "$BODY")"
    BOXES="$(printf '%s\n' "$TESTING" | grep -c '^[[:space:]]*- \[[ xX]\] ')"
    [ "$BOXES" -ge 2 ] \
      || err "Testing needs 2+ '- [ ] ' items, each naming a real path or behavior from the diff"
  fi

  # An unfilled placeholder is bracketed text containing a space that is not a
  # markdown link, a reference link or definition, or a checkbox — so
  # `[Key change 1]` fails while `[the docs](url)`, `[spec][ref]`,
  # `[my ref]: url` and `[1]` pass. Only the checkbox marker is stripped (in any
  # list style), so a placeholder written after one is still caught.
  PLACE="$(printf '%s\n' "$PROSE" \
           | sed -E 's/^([[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]+)\[[ xX]\]/\1/' \
           | grep -nE '\[[^]]*[[:space:]][^]]*\]([^([]|$)' \
           | grep -vE '^[0-9]+:[[:space:]]{0,3}\[[^]]+\]:' | head -1)"
  [ -n "$PLACE" ] && err "unfilled placeholder: $PLACE"
  printf '%s\n' "$PROSE" | grep -qiE 'key change [0-9]|verification criterion|high-level overview|brief description of|detail [0-9]' \
    && err "template boilerplate left in the body — write the real content"

  # Provenance greps run on the code-stripped prose, so a body that
  # legitimately QUOTES an attribution string in backticks (e.g. a PR about
  # this very lint) does not trip the wall.
  PROV_STRIP="$(mktemp)"
  printf '%s\n' "$PROSE" > "$PROV_STRIP"
  PROV_FILE="$PROV_STRIP"; PROV_WHAT="PR body"
  # --- provenance wall (identical block in git-commit/scripts/commit-preflight.sh)
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

  if [ -n "$TITLE" ]; then
    [ "${#TITLE}" -le 70 ] || err "title is ${#TITLE} chars (max 70)"
    case "$TITLE" in *.) err "title ends with a period";; esac
    if [ "$(title_style)" = conventional ]; then
      printf '%s\n' "$TITLE" | grep -qE "^($TYPES)(\([a-z0-9._-]+\))?!?: .+" \
        || err "this repo titles commits conventionally — use 'type(scope): description'"
    fi
  fi

  [ "$FAIL" = 0 ] && echo "lint: PR body OK"
  exit "$FAIL"
fi

# ---- preflight report
echo "== PR PREFLIGHT =="
command -v gh >/dev/null 2>&1 \
  || { echo "ABORT: gh is not installed — https://cli.github.com/, then 'gh auth login'."; exit 1; }
gh auth status >/dev/null 2>&1 \
  || { echo "ABORT: gh is not authenticated — run 'gh auth login'."; exit 1; }

HEAD_BRANCH="$(git branch --show-current)"
[ -n "$HEAD_BRANCH" ] || { echo "ABORT: detached HEAD — check out a branch first."; exit 1; }

# Whatever this branch actually tracks, falling back to origin.
REMOTE="$(git config --get "branch.$HEAD_BRANCH.remote" 2>/dev/null)"
[ -n "$REMOTE" ] || REMOTE=origin

BASE="${1:-}"; SRC="argument"
if [ -z "$BASE" ]; then
  SRC="repo default"
  BASE="$(git symbolic-ref --quiet --short "refs/remotes/$REMOTE/HEAD" 2>/dev/null | sed "s#^$REMOTE/##")"
  [ -n "$BASE" ] || BASE="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)"
fi
[ -n "$BASE" ] || { echo "ABORT: no base branch given and the repo default did not resolve — pass one."; exit 1; }
[ "$BASE" != "$HEAD_BRANCH" ] || { echo "ABORT: already on '$BASE' — check out a feature branch first."; exit 1; }

# Captured here, judged after the merge base is known: push ships commits, not
# the working tree, so dirty files are a problem only when they intersect this
# PR's own diff — the one case where the tree and what the reviewer sees could
# genuinely diverge.
DIRTY="$(git status --porcelain | grep -v '^??')"

git remote get-url "$REMOTE" >/dev/null 2>&1 \
  || { echo "ABORT: remote '$REMOTE' is not configured — 'git remote -v' lists what is."; exit 1; }

# Fetch the base AND this branch: the behind-check below is worthless against a
# stale remote-tracking ref. A fetch failure is not proof the branch is missing,
# so fall back to the cached ref and say the report may be stale.
if ! FETCH_ERR="$(git fetch --quiet "$REMOTE" "$BASE" "$HEAD_BRANCH" 2>&1)"; then
  FETCH_ERR="$(git fetch --quiet "$REMOTE" "$BASE" 2>&1)" || {
    if git rev-parse --verify --quiet "$REMOTE/$BASE" >/dev/null 2>&1; then
      # A decision point, not a silent fallback: the model reads the raw error
      # and judges the cause before trusting anything derived from the ref.
      echo "WARN: fetch failed — push, behind, and merge-risk results below read the"
      echo "      cached $REMOTE/$BASE and may be stale. Diagnose the error before"
      echo "      trusting them (expired auth? network? remote moved?):"
      printf '%s\n' "$FETCH_ERR" | sed 's/^/    /'
    else
      echo "ABORT: cannot resolve '$REMOTE/$BASE':"
      printf '%s\n' "$FETCH_ERR" | sed 's/^/    /'
      exit 1
    fi
  }
fi

MB="$(git merge-base "$REMOTE/$BASE" HEAD 2>/dev/null)"
[ -n "$MB" ] \
  || { echo "ABORT: no merge base with $REMOTE/$BASE — shallow clone? try 'git fetch --unshallow'."; exit 1; }

COMMITS="$(git log --oneline "$MB..HEAD" 2>/dev/null)"
[ -n "$COMMITS" ] \
  || { echo "ABORT: no commits between $REMOTE/$BASE and HEAD — nothing to open a PR for."; exit 1; }

if [ -n "$DIRTY" ]; then
  DIRTY_PATHS="$(printf '%s\n' "$DIRTY" | sed -E 's/^.{3}//; s/^.* -> //')"
  OVERLAP="$(comm -12 <(printf '%s\n' "$DIRTY_PATHS" | sort -u) \
                      <(git diff --name-only "$MB" HEAD | sort -u))"
  if [ -n "$OVERLAP" ]; then
    echo "ABORT: uncommitted changes touch files in this PR's diff — commit or stash them first:"
    printf '%s\n' "$OVERLAP" | sed 's/^/    /'
    exit 1
  fi
  echo "WARN: uncommitted local changes, none in this PR's diff — push ships commits"
  echo "      only, so proceeding; the PR will not include:"
  printf '%s\n' "$DIRTY" | sed 's/^/    /'
fi

PUSH=""
if UP="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"; then
  set -- $(git rev-list --left-right --count "HEAD...$UP")
  AHEAD="${1:-0}"; BEHIND="${2:-0}"
  [ "$BEHIND" = 0 ] \
    || { echo "ABORT: $UP has $BEHIND commit(s) you do not — pull or rebase first (this skill never force-pushes)."; exit 1; }
  [ "$AHEAD" = 0 ] || PUSH="git push"
else
  PUSH="git push -u $REMOTE $HEAD_BRANCH"
fi

# A swallowed query failure would read as "no PR open" and make the agent open a
# second PR on a branch that already has one.
if ! PR="$(gh pr list --head "$HEAD_BRANCH" --state open \
           --json number,url,baseRefName,isDraft \
           --jq '.[] | "\(.number)\t\(.url)\t\(.baseRefName)\t\(.isDraft)"' 2>&1)"; then
  if printf '%s\n' "$PR" | grep -qiE 'no git remotes|known github host|could not determine'; then
    echo "ABORT: '$REMOTE' does not point at a GitHub host — gh cannot open a PR here."
  else
    echo "ABORT: could not query existing PRs — refusing to risk opening a duplicate:"
  fi
  printf '%s\n' "$PR" | sed 's/^/    /'
  exit 1
fi
PR="$(printf '%s\n' "$PR" | head -1)"

echo "base:  $BASE  (source: $SRC, remote: $REMOTE)"
echo "push:  ${PUSH:-not needed — remote is up to date}"
if [ -n "$PR" ]; then
  IFS=$'\t' read -r PR_NUM PR_URL PR_BASE PR_DRAFT <<<"$PR"
  echo "pr:    #$PR_NUM open  $PR_URL  base=$PR_BASE draft=$PR_DRAFT"
  [ "$PR_BASE" = "$BASE" ] \
    || echo "       NOTE: the open PR targets '$PR_BASE', you asked for '$BASE' — keep its base unless the user asked to retarget"
  ACTION="UPDATE the body of #$PR_NUM (gh pr edit $PR_NUM --body-file)"
else
  echo "pr:    none open for this branch"
  ACTION="CREATE a PR (gh pr create --base $BASE --title ... --body-file)"
fi
TPL="$(find_template)"; TPLDIR="$(template_dir)"
if [ -n "$TPL" ]; then
  # gh pr create --body-file never applies the repo template, so the body
  # written here is the only one the reviewer gets. Show the shape that is
  # enforced, not the template's prose.
  echo "template: $TPL  (fill THIS shape — gh does not apply it for you)"
  SHAPE="$(template_shape "$TPL" | head -25)"
  if [ -n "$SHAPE" ]; then
    printf '%s\n' "$SHAPE" | sed 's/^/    /'
  else
    echo "    (no headings, labels, or checklist items — read $TPL and match it by hand)"
  fi
elif [ -n "$TPLDIR" ]; then
  echo "template: several in $TPLDIR — none applies automatically; pick the one that fits"
  echo "          (--lint checks the body against whichever it matches best)"
  ls "$TPLDIR" | sed 's/^/    /'
else
  echo "template: none — use the body template in SKILL.md"
fi
echo "title style: $(title_style)"

# One diff walk feeds the stat display, the composition, the totals and the
# deleted-file list.
NUMSTAT="$(git diff --numstat "$MB" HEAD)"
DELETED="$(git diff --diff-filter=D --name-only "$MB" HEAD)"

# What counts as generated is the repo's call, not this script's guess: any path
# the repo marks linguist-generated or linguist-vendored in .gitattributes is
# authoritative. The extension list in the bucketer is only the fallback for
# repos that declare nothing.
DECLARED="$(printf '%s\n' "$NUMSTAT" \
  | awk -F'\t' 'NF >= 3 { print $3 }' \
  | sed -E 's/\{[^}]* => //; s/\}//; s/^.* => //' \
  | git check-attr --stdin linguist-generated linguist-vendored 2>/dev/null \
  | sed -nE 's/: linguist-(generated|vendored): set$//p' | sort -u)"

echo
echo "-- commits ($REMOTE/$BASE..HEAD) --"; echo "$COMMITS" | sed 's/^/    /'
echo "-- files changed --"
printf '%s\n' "$NUMSTAT" | awk -F'\t' '{ printf "    %6s %-6s %s\n", "+"$1, "-"$2, $3 }'

# Generated-or-not is the only classification here, because it is the only one
# that can be answered without a model of what kind of project this is: the repo
# declares it in .gitattributes, and the fallback covers only files that are
# generated in every ecosystem. Anything that would need to know what a "test"
# or a "migration" looks like in this language is left to the diff, which the
# model now reads in full.
# MODE=paths re-runs the same predicate to emit the generated paths, so the diff
# command below excludes exactly what the report says it excludes.
CLASSIFIER='
BEGIN { n = split(DECLARED, d, "\n"); for (i = 1; i <= n; i++) if (d[i] != "") declared[d[i]] = 1 }
function generated(p,   lp) {
  if (p in declared) return 1
  lp = tolower(p)
  if (lp ~ /(^|\/)(node_modules|vendor|__snapshots__)\//) return 1
  if (lp ~ /(\.lock|\.lockb|-lock\.json|\.snap|\.min\.[a-z]+)$/) return 1
  return 0
}
{
  path = $3
  if (path ~ /\{.* => /) { sub(/\{[^}]* => /, "", path); sub(/\}/, "", path) }
  else if (path ~ / => /) { sub(/^.* => /, "", path) }
  g = generated(path)
  if (MODE == "paths") { if (g) print path; next }
  if ($1 != "-") { if (g) gen += $1 + $2; else rev += $1 + $2 }
}
END { if (MODE != "paths") printf "%d %d\n", rev + 0, gen + 0 }'

read -r REV GEN <<<"$(printf '%s\n' "$NUMSTAT" | awk -F'\t' -v MODE=report -v DECLARED="$DECLARED" "$CLASSIFIER")"

# Exclude the generated paths from the diff the model is told to read, rather
# than printing the full diff and asking it in prose to skip them.
EXCLUDES=""
while IFS= read -r p; do
  [ -n "$p" ] && EXCLUDES="$EXCLUDES ':(exclude)$p'"
done < <(printf '%s\n' "$NUMSTAT" | awk -F'\t' -v MODE=paths -v DECLARED="$DECLARED" "$CLASSIFIER")
[ -n "$EXCLUDES" ] && EXCLUDES=" -- .$EXCLUDES"

# Merge risk: git facts only, no guessing. merge-tree does a real merge in
# memory, so [conflict] names files that actually conflict rather than files
# that merely changed on both sides.
BEHIND_BASE="$(git rev-list --count "$MB..$REMOTE/$BASE" 2>/dev/null)"
MT="$(git merge-tree --write-tree --name-only "$REMOTE/$BASE" HEAD 2>&1)"; MT_RC=$?
CONFLICTS=""
case "$MT_RC" in
  0) ;;
  1) CONFLICTS="$(printf '%s\n' "$MT" | awk 'NR == 1 { next } /^$/ { exit } { print }')" ;;
  *) CONFLICTS="" ;;
esac

echo
echo "-- merge risk --"
RISK=0
if [ -n "$CONFLICTS" ]; then
  echo "    [conflict] real conflicts with $REMOTE/$BASE — rebase before opening:"
  printf '%s\n' "$CONFLICTS" | head -20 | sed 's/^/        /'
  RISK=1
elif [ "$MT_RC" -gt 1 ]; then
  echo "    [conflict] not checked — git merge-tree unavailable here"
fi
if [ "${BEHIND_BASE:-0}" -gt 0 ]; then
  echo "    [stale]    $REMOTE/$BASE is $BEHIND_BASE commit(s) ahead of your merge base"
  RISK=1
fi
if [ -n "$DELETED" ]; then
  DEL_N="$(printf '%s\n' "$DELETED" | grep -c .)"
  echo "    [deleted]  $DEL_N file(s) removed — callers of them break on merge:"
  printf '%s\n' "$DELETED" | head -20 | sed 's/^/        /'
  [ "$DEL_N" -gt 20 ] && echo "        ...and $((DEL_N - 20)) more"
  RISK=1
fi
[ "$RISK" = 0 ] && echo "    none"

echo
if [ "${GEN:-0}" -gt 0 ]; then
  echo "reading: $REV reviewable lines, $GEN generated (already excluded below)"
else
  echo "reading: $REV reviewable lines"
fi
[ "${REV:-0}" -gt 500 ] && echo "         (>500 — read path by path, not all at once)"
echo "diff: git diff $MB HEAD$EXCLUDES"
echo
echo "action: ${PUSH:+$PUSH, then }$ACTION"
echo "== END PREFLIGHT — read the diff, write the body, --lint it, then act =="
