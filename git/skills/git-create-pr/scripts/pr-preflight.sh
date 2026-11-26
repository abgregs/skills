#!/usr/bin/env bash
# pr-preflight.sh — deterministic detector for the /git-create-pr skill.
# Two modes:
#   pr-preflight.sh [base]                  preflight report (tooling, base,
#                                           push state, existing PR, repo
#                                           template, title style, diff) plus
#                                           the action to take
#   pr-preflight.sh --lint <body> [--title-file <file>] [--existing <file>] [--keep <file>] [--accept-warnings]
#                                           lint a PR body written to a file,
#                                           and the title in its file if given;
#                                           --existing is the current body of
#                                           the PR being updated, whose kept
#                                           lines must survive, and --keep lists
#                                           more lines that must; exit 0 = OK,
#                                           1 = violations, 2 = warnings only
#   pr-preflight.sh --ship <body> [--title-file <file>] [--base <branch>] [--accept-warnings]
#                                           the only path to GitHub: preflight
#                                           again, lint, then push and create or
#                                           update; exit 0 = shipped; on a stop,
#                                           a NOT SHIPPED line and 1 = the gate
#                                           refused or the lint failed, 2 = the
#                                           lint warned, 3 = the preflight
#                                           stopped, 4 = the pre-push hook
#                                           failed, 5 = the push or gh failed;
#                                           a stop that repeats the last one
#                                           says to hand back
#
# Only --ship mutates, and only after the lint passes; the other modes never
# touch the working tree, the index, or any local branch. Hook and gh output
# pass through --ship, so it lands in the model's context. Every mode that
# reads the base DOES fetch — that writes remote-tracking refs and objects,
# which the base comparison depends on.
#
# It owns everything regex-checkable; the model owns what the PR says.
# No `set -e` — a zero-match grep must not abort the report.
set -u

# Read-only by default: no index refresh, and raw UTF-8 paths so the bucketer
# and the deleted-file list see real filenames rather than octal escapes.
git() { command git --no-optional-locks -c core.quotePath=false "$@"; }

# A relative --lint path belongs to the caller's cwd; remember it before the cd
# below moves us to the repo root.
CALLER="$PWD"
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
abspath() { case "$1" in /*) printf '%s\n' "$1" ;; *) printf '%s\n' "$CALLER/$1" ;; esac; }

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

# Lines people add to a PR in GitHub that a rewrite of the body must not lose:
# ticked boxes, images and attachments, and closing keywords (`Closes #12`).
# Read from the rendered text, leading whitespace dropped so a kept line can
# move to a different nesting level and still match.
keep_lines() {
  md_visible "$1" | sed -E 's/^[[:space:]]+//' | grep -iE \
    -e '^[-*+] \[[xX]\] ' \
    -e '!\[[^]]*\]\([^)]+\)' -e '<img[[:space:]]' -e 'github\.com/user-attachments/' \
    -e '(^|[^[:alnum:]])(close[sd]?|fix(e[sd])?|resolve[sd]?):?[[:space:]]+([[:alnum:]_.-]+/[[:alnum:]_.-]+)?#[0-9]+' \
    -e '(^|[^[:alnum:]])(close[sd]?|fix(e[sd])?|resolve[sd]?):?[[:space:]]+https://github\.com/[^[:space:]]+/issues/[0-9]+' \
    | awk '!seen[$0]++'
}

# One body's visible lines as a sorted set, for comparing versions.
line_set() { md_visible "$1" | sed -E 's/^[[:space:]]+//' | grep -v '^$' | sort -u; }

# Lines other people added to the body since the PR opened, still in it now,
# as "login<TAB>line". GitHub keeps every saved version of a PR body with the
# login that saved it; a line first seen in a version saved by another login
# is theirs. The first version is the PR as opened, so it is the baseline, not
# an addition. This skill runs as the user, so the user's own edits share its
# login and are not told apart here. Exit 1 when the history does not load.
other_people_lines() { # <pr-url> <pr-number> <current-body-file>
  local slug owner name dir me n i login prev
  slug="$(printf '%s' "$1" | sed -nE 's#^https?://[^/]+/([^/]+)/([^/]+)/pull/[0-9]+.*#\1/\2#p')"
  [ -n "$slug" ] || return 1
  owner="${slug%%/*}"; name="${slug#*/}"
  dir="$(mktemp -d "${TMPDIR:-/tmp}/pr-history.XXXXXX")"
  if ! gh api graphql -f owner="$owner" -f name="$name" -F number="$2" \
       -f query='query($owner:String!,$name:String!,$number:Int!){viewer{login} repository(owner:$owner,name:$name){pullRequest(number:$number){userContentEdits(first:100){nodes{editedAt editor{login} diff}}}}}' \
       --jq '.data.viewer.login, (.data.repository.pullRequest.userContentEdits.nodes | sort_by(.editedAt) | .[] | "\u001e\(.editor.login // "")", (.diff // ""))' \
       > "$dir/raw" 2>/dev/null; then
    rm -r "$dir"; return 1
  fi
  me="$(head -1 "$dir/raw")"
  # Split the stream into one file per version (v1, v2, ...) and its login (l1, ...).
  awk -v d="$dir" '
    NR == 1 { next }
    /^\036/ { n++; sub(/^\036/, ""); print > (d "/l" n); close(d "/l" n); printf "" > (d "/v" n); next }
    n { print >> (d "/v" n) }' "$dir/raw"
  n="$(ls "$dir" | grep -c '^v')"
  line_set "$3" > "$dir/now"
  i=2
  while [ "$i" -le "$n" ]; do
    login="$(cat "$dir/l$i")"; prev=$((i - 1))
    if [ -n "$login" ] && [ "$login" != "$me" ]; then
      comm -13 <(line_set "$dir/v$prev") <(line_set "$dir/v$i") | comm -12 - "$dir/now" \
        | sed "s/^/$login	/"
    fi
    i=$((i + 1))
  done | awk -F'\t' '!seen[$2]++'
  rm -r "$dir"
}

# When the PR body was last saved, as GitHub records it: the last edit, or the
# PR's opening when nobody has edited it. Empty when the query fails.
body_saved_at() { # <pr-url> <pr-number>
  local slug
  slug="$(printf '%s' "$1" | sed -nE 's#^https?://[^/]+/([^/]+)/([^/]+)/pull/[0-9]+.*#\1/\2#p')"
  [ -n "$slug" ] || return 0
  gh api graphql -f owner="${slug%%/*}" -f name="${slug#*/}" -F number="$2" \
    -f query='query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){pullRequest(number:$number){createdAt lastEditedAt}}}' \
    --jq '.data.repository.pullRequest | (.lastEditedAt // .createdAt)' 2>/dev/null \
    | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' | head -1
}

# The hook that made a git command fail, read from its GIT_TRACE2_PERF file: the
# top-level process's (depth d0) child of class hook whose exit code is not 0.
# Git commands a hook runs itself trace at depth d1 and are left out. Empty when
# no hook failed, or when git is too old for trace2.
failed_hook() { # <trace-file>
  awk -F'|' '
    $2 ~ /^ *d0 *$/ && $4 ~ /child_start/ && match($NF, /\[ch[0-9]+\] class:hook hook:[A-Za-z_-]+/) {
      s = substr($NF, RSTART, RLENGTH); id = s; sub(/^\[ch/, "", id); sub(/\].*/, "", id)
      name = s; sub(/.*hook:/, "", name); hook[id] = name }
    $2 ~ /^ *d0 *$/ && $4 ~ /child_exit/ && match($NF, /\[ch[0-9]+\] pid:-?[0-9]+ code:-?[0-9]+/) {
      s = substr($NF, RSTART, RLENGTH); id = s; sub(/^\[ch/, "", id); sub(/\].*/, "", id)
      code = s; sub(/.*code:/, "", code)
      if ((id in hook) && code != 0) failed = hook[id] }
    END { print failed }' "$1" 2>/dev/null
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

# The title crosses as a file, like the body, so no shell quoting stands between
# what the agent wrote and what GitHub gets: a backtick, a `$`, or an apostrophe
# arrives as typed. One non-blank line, trailing whitespace dropped.
TITLE_HINT="       a title goes in its own file, passed with --title-file, so the shell never touches it"
read_title() { grep -v '^[[:space:]]*$' "$1" | sed -E 's/[[:space:]]+$//'; }

if [ "${1:-}" = "--lint" ]; then
  USAGE="usage: pr-preflight.sh --lint <body-file> [--title-file <file>] [--existing <current-body-file>] [--keep <lines-file>] [--accept-warnings]"
  [ -n "${2:-}" ] || { echo "$USAGE"; exit 1; }
  BODY="$(abspath "$2")"; shift 2
  TITLEF=""; EXIST=""; KEEPX=""; ACCEPT=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --title-file) [ -n "${2:-}" ] || { echo "$USAGE"; exit 1; }; TITLEF="$(abspath "$2")"; shift 2 ;;
      --existing) [ -n "${2:-}" ] || { echo "$USAGE"; exit 1; }; EXIST="$(abspath "$2")"; shift 2 ;;
      --keep) [ -n "${2:-}" ] || { echo "$USAGE"; exit 1; }; KEEPX="$(abspath "$2")"; shift 2 ;;
      --accept-warnings) ACCEPT=1; shift ;;
      *) echo "$USAGE"; echo "$TITLE_HINT"; exit 1 ;;
    esac
  done
  [ -f "$BODY" ] || { echo "lint: no such file: $BODY"; exit 1; }
  [ -s "$BODY" ] || { echo "LINT FAIL: body is empty"; exit 1; }
  [ -z "$EXIST" ] || [ -f "$EXIST" ] || { echo "lint: no such file: $EXIST"; exit 1; }
  [ -z "$KEEPX" ] || [ -f "$KEEPX" ] || { echo "lint: no such file: $KEEPX"; exit 1; }
  [ -z "$TITLEF" ] || [ -f "$TITLEF" ] || { echo "lint: no such file: $TITLEF"; exit 1; }
  FAIL=0; WARNED=0
  err() { echo "LINT FAIL: $1"; FAIL=1; }
  warn() { echo "LINT WARN: $1"; WARNED=1; }
  TITLE=""
  if [ -n "$TITLEF" ]; then
    TITLE="$(read_title "$TITLEF")"
    TN="$(printf '%s' "$TITLE" | grep -c .)"
    if [ "$TN" = 0 ]; then err "the title file is empty — write the title on its one line"
    elif [ "$TN" -gt 1 ]; then err "the title file holds $TN lines — a title is one line"; TITLE=""; fi
  fi

  # An update keeps what people added to the PR in GitHub: the kept shapes in
  # the current body (--existing), and the lines other people typed (--keep,
  # from the preflight's read of the body's history). Each kept line must
  # appear in the new body, and is then exempt from the checks below: it is
  # their text, not the agent's, so a ticked box there stays ticked.
  BODY_VIS="$(md_visible "$BODY")"
  BODY_TRIM="$(printf '%s\n' "$BODY_VIS" | sed -E 's/^[[:space:]]+//')"
  KEEPF="$(mktemp "${TMPDIR:-/tmp}/pr-keep.XXXXXX")" \
    || { echo "LINT FAIL: no temp file under ${TMPDIR:-/tmp}, so the kept lines cannot be checked"; exit 1; }
  { [ -z "$EXIST" ] || keep_lines "$EXIST"
    [ -z "$KEEPX" ] || sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' "$KEEPX" | grep -v '^$'
  } | awk '!seen[$0]++' > "$KEEPF"
  KEEPN=""
  if [ -s "$KEEPF" ]; then
    while IFS= read -r K; do
      [ -z "$K" ] || printf '%s\n' "$BODY_TRIM" | grep -qxF -- "$K" \
        || err "line from the current PR body is missing — carry it over verbatim: $K"
    done < "$KEEPF"
    KEEPN=" $(printf '%s\n' "$BODY_TRIM" | grep -nxF -f "$KEEPF" | cut -d: -f1 | tr '\n' ' ')"
  fi
  blank_kept() { awk -v L="$KEEPN " '{ if (index(L, " " NR " ")) print ""; else print }'; }

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
    { print; prev = ($0 ~ /^[[:space:]]*$/) ? "blank" : "text" }' "$BODY" | sed 's/`[^`]*`//g' | blank_kept)"

  TPL="$(find_template)"; TPLDIR="$(template_dir)"
  if [ -n "$TPL" ]; then
    MISS="$(template_misses "$TPL")"
    if [ "$MISS" = NOREQ ]; then
      echo "LINT NOTE: $TPL has no headings, labels, or checklist items — match its shape by hand"
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
      echo "LINT NOTE: no template in $TPLDIR has headings, labels, or checklist items — match the chosen one by hand"
    else
      while IFS= read -r M; do
        [ -z "$M" ] || err "closest repo template ($BEST) $M"
      done <<<"$BEST_MISS"
    fi
  else
    for H in '## Summary' '## Changes' '## Testing'; do
      grep -qxF -- "$H" "$BODY" || err "missing required section: $H"
    done
    # Count inside the Testing section: plain bullets under Verified: are
    # evidence, unticked boxes under For the reviewer: are work. A ticked box
    # claims a check without showing it, so it fails here; repo templates keep
    # their own checkbox rules above.
    TESTING="$(awk '/^##[[:space:]]+Testing/ { f = 1; next } /^##[[:space:]]/ { f = 0 } f' "$BODY")"
    ITEMS="$(printf '%s\n' "$TESTING" | grep -c '^[[:space:]]*- ')"
    [ "$ITEMS" -ge 2 ] \
      || err "Testing needs 2+ items, each naming a real path or behavior from the diff"
    while IFS= read -r HIT; do
      err "ticked box in Testing — write it under 'Verified:' as a plain bullet with its result: $HIT"
    done < <(printf '%s\n' "$TESTING" | grep '^[[:space:]]*- \[[xX]\] ' \
          | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' \
          | { if [ -s "$KEEPF" ]; then grep -vxF -f "$KEEPF"; else cat; fi; })
    # Verified: holds checks that ran. A label with nothing under it, or with
    # only bullets saying nothing ran ("None run in this session."), promises
    # evidence the section does not hold, so the label goes when nothing ran.
    # A real result with a caveat ("passed; the UI test did not run") stays.
    VER="$(printf '%s\n' "$TESTING" | awk '
      /^[[:space:]]*\**Verified:\**[[:space:]]*$/ { v = 1; seen = 1; next }
      /^[[:space:]]*\**For the reviewer:\**/ { v = 0; next }
      v && /^[[:space:]]*[-*+] / {
        n++; t = tolower($0); sub(/^[[:space:]]*[-*+] +/, "", t)
        if (t ~ /^(none|nothing|n\/a|no (checks?|tests?)|not (yet )?run|did not run)([^[:alnum:]]|$)/) e++ }
      END { if (seen) print n + 0, e + 0 }')"
    if [ -n "$VER" ]; then
      read -r VN VE <<<"$VER"
      { [ "$VN" -gt 0 ] && [ "$VE" -lt "$VN" ]; } \
        || err "Verified: holds no check that ran — leave the label out when nothing ran, and keep the work under For the reviewer:"
    fi
    # Impact holds what a reviewer must weigh, and its absence says there is
    # nothing. A line saying so ("no behavior change", "user-visible text only")
    # repeats the absence: every recorded Impact that belonged out said it in one
    # of these shapes. A warning, since the phrase can sit beside a consequence.
    NOWEIGH='(^|[^[:alnum:]])(no (breaking|behaviou?r(al)?|functional|runtime|logic|code|api|user-(visible|facing)) changes?|(user-(visible|facing)|visible|display|ui) (text|strings?|copy) only|only (the )?(user-(visible|facing) |visible |display |ui )?(text|strings?|copy|wording) changes?|(docs?|documentation|comments?|cosmetic|text|copy)[- ]only|no impact|nothing to weigh)([^[:alnum:]]|$)'
    while IFS= read -r HIT; do
      warn "Impact line says the change carries nothing to weigh — delete the line, and the section when nothing else is left: ${HIT%%:*}:$(sed -n "${HIT%%:*}p" "$BODY")"
    done < <(printf '%s\n' "$PROSE" | awk '/^##[[:space:]]+Impact/ { f = 1; next } /^##[[:space:]]/ { f = 0 } f { print NR ":" $0 }' \
          | grep -iE "^[0-9]+:.*$NOWEIGH")
  fi

  # An unfilled placeholder is bracketed text containing a space that is not a
  # markdown link, a reference link or definition, or a checkbox — so
  # `[Key change 1]` fails while `[the docs](url)`, `[spec][ref]`,
  # `[my ref]: url` and `[1]` pass. Only the checkbox marker is stripped (in any
  # list style), so a placeholder written after one is still caught. Every hit
  # is reported, so one rewrite clears them all.
  while IFS= read -r HIT; do err "unfilled placeholder: $HIT"; done \
    < <(printf '%s\n' "$PROSE" \
        | sed -E 's/^([[:space:]]*([-*+]|[0-9]+[.)])[[:space:]]+)\[[ xX]\]/\1/' \
        | grep -nE '\[[^]]*[[:space:]][^]]*\]([^([]|$)' \
        | grep -vE '^[0-9]+:[[:space:]]{0,3}\[[^]]+\]:')
  while IFS= read -r HIT; do err "template boilerplate left in the body — write the real content: $HIT"; done \
    < <(printf '%s\n' "$PROSE" | grep -niE 'key change [0-9]|verification criterion|high-level overview|brief description of|detail [0-9]')

  # Provenance greps run on the code-stripped prose, so a body that
  # legitimately QUOTES an attribution string in backticks (e.g. a PR about
  # this very lint) does not trip the wall. A ```mermaid block is the
  # exception: GitHub renders it as a diagram, so its labels reach the reviewer
  # like prose and go back in, line for line.
  MERMAID="$(awk '
    /^[[:space:]]*(```|~~~)/ {
      t = $0; sub(/^[[:space:]]*/, "", t)
      if (f == "") { f = substr(t, 1, 3); m = (t ~ /^(```|~~~)[[:space:]]*mermaid([[:space:]]|$)/) }
      else if (substr(t, 1, 3) == f) { f = ""; m = 0 }
      print ""; next
    }
    f != "" && m { print; next }
    { print "" }' "$BODY")"
  # A template under TMPDIR: on macOS a bare mktemp ignores TMPDIR, and a
  # sandbox that denies the default temp dir would leave the check no file.
  PROV_STRIP="$(mktemp "${TMPDIR:-/tmp}/pr-prov.XXXXXX")" \
    || { echo "LINT FAIL: no temp file under ${TMPDIR:-/tmp}, so the provenance check cannot run"; exit 1; }
  awk 'NR == FNR { m[FNR] = $0; next } { print ($0 == "" && (FNR in m)) ? m[FNR] : $0 }' \
    <(printf '%s\n' "$MERMAID") <(printf '%s\n' "$PROSE") > "$PROV_STRIP"
  PROV_FILE="$PROV_STRIP"; PROV_WHAT="PR body"; PROV_ORIG="$BODY"
  # --- provenance wall (identical block in git-commit/scripts/commit-preflight.sh)
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

  # Every hit is reported, not only the first, so one rewrite clears them all.
  while IFS= read -r HIT; do err "authorship trailer in the $PROV_WHAT: $HIT"; done \
    < <(grep -niE "^[[:space:]]*(co-authored-by|authored-by|assisted-by|generated-by):" "$PROV_FILE")

  while IFS= read -r HIT; do err "attribution byline in the $PROV_WHAT: $HIT"; done \
    < <(grep -niE -- "$BYLINE" "$PROV_FILE" | grep -iE -- "$NAMED|https?://")

  while IFS= read -r HIT; do err "link to an agent or session in the $PROV_WHAT: $HIT"; done \
    < <(grep -niE 'claude\.ai|claude\.com/claude-code|chatgpt\.com|chat\.openai\.com|cursor\.com|copilot-workspace|githubcopilot' "$PROV_FILE")

  while IFS= read -r HIT; do err "agent marker emoji in the $PROV_WHAT: $HIT"; done \
    < <(grep -n '🤖' "$PROV_FILE")
  # --- end provenance wall ---
  # --- clarity warnings (identical block in git-commit/scripts/commit-preflight.sh)
  # needs from the caller: PROV_FILE, PROV_WHAT, PROV_ORIG (the unstripped file, for quoting), warn()
  # The slice of Simplified Technical English that fits prose quoting
  # identifiers: no gerund bullets, no hedging verbs, no vague openers. Warnings,
  # not failures — each has a legitimate exception ("May 2026", a noun that ends
  # in -ing) that the skill's read-through can judge. Matched on the
  # code-stripped copy, reported from the original so the line reads whole.
  # Every hit is reported, not only the first, so one rewrite clears them all.
  BULLET='[[:space:]]*- (\[[ xX]\] )?'
  orig_line() { echo "$1:$(sed -n "${1}p" "$PROV_ORIG")"; }
  while IFS= read -r HIT; do warn "bullet opens with an -ing word — start it with the code that acts: $(orig_line "${HIT%%:*}")"; done \
    < <(grep -nE "^${BULLET}[A-Za-z]+ing([^[:alnum:]]|\$)" "$PROV_FILE" \
        | grep -viE "^[0-9]+:${BULLET}(bring|string|during|thing|nothing|something|anything|everything|ring|sing|king|wing|swing|spring)([^[:alnum:]]|\$)")
  while IFS= read -r HIT; do warn "hedge word in the $PROV_WHAT — state what the code does, or name the risk outright: $(orig_line "${HIT%%:*}")"; done \
    < <(grep -niE '(^|[^[:alnum:]])(should|would|may|might|probably|hopefully|possibly)([^[:alnum:]]|$)' "$PROV_FILE")
  while IFS= read -r HIT; do warn "vague opener in a bullet — name what changed: $(orig_line "${HIT%%:*}")"; done \
    < <(grep -niE "^${BULLET}(improves?|cleans? ?up|cleanup|tweaks?|polish(es)?|enhances?|various|some|misc|miscellaneous|minor)([^[:alnum:]]|\$)" "$PROV_FILE")
  # --- end clarity warnings ---
  rm -f "$PROV_STRIP" "$KEEPF"

  # The countable half of the diagram rule; whether to draw, and what, stays
  # with the model. One ```mermaid block, inside ## Summary (when the body uses
  # the skill's template), of a type GitHub renders reliably; warnings for a
  # diagram past about 12 nodes or 12 messages, and for an unquoted label with
  # punctuation, which breaks the render.
  [ -n "$TPL$TPLDIR" ] && TPLMODE=1 || TPLMODE=0
  while IFS=$'\t' read -r KIND MSG; do
    case "$KIND" in FAIL) err "$MSG" ;; WARN) warn "$MSG" ;; esac
  done < <(awk -v tpl="$TPLMODE" '
    function check(   i, j, k, s, w, ty, cnt, msgs, ids) {
      if (!tpl && bsec != "## Summary")
        print "FAIL\tthe mermaid block at line " start " sits under " (bsec == "" ? "no section" : bsec) " — a diagram goes at the end of ## Summary"
      ty = ""
      for (i = 1; i <= n; i++) {
        s = L[i]; if (s ~ /^[[:space:]]*$/ || s ~ /^[[:space:]]*%%/) continue
        sub(/^[[:space:]]+/, "", s); split(s, w, /[[:space:]]+/); ty = w[1]; break
      }
      if (ty != "flowchart" && ty != "sequenceDiagram" && ty != "stateDiagram-v2") {
        print "FAIL\tthe mermaid block at line " start " is " (ty == "" ? "empty" : "a " ty) " — keep to flowchart, sequenceDiagram, or stateDiagram-v2"
        return
      }
      cnt = 0; msgs = 0; split("", ids)
      for (i = 1; i <= n; i++) {
        s = L[i]; if (s ~ /^[[:space:]]*$/ || s ~ /^[[:space:]]*%%/) continue
        if (ty == "sequenceDiagram") { if (s ~ /(-|--)(>>|>|x|\))/ && s ~ /:/) msgs++; continue }
        if (ty == "flowchart" && (s ~ /\[[^]"]*[(){}][^]"]*\]/ || s ~ /\{[^}"]*[()][^}"]*\}/))
          print "WARN\tline " (start + i) ": a mermaid label with punctuation needs double quotes, as in A[\"parse(input)\"]"
        if (s ~ /^[[:space:]]*(flowchart|stateDiagram-v2|subgraph|end|direction|classDef|class|style|linkStyle|click|note)([[:space:]]|$)/) continue
        gsub(/"[^"]*"/, "", s); gsub(/\[[^]]*\]|\([^)]*\)|\{[^}]*\}|\|[^|]*\|/, " ", s)
        if (ty == "stateDiagram-v2") sub(/:.*/, "", s)
        gsub(/[^A-Za-z0-9_]+/, " ", s); k = split(s, w, " ")
        for (j = 1; j <= k; j++)
          if (w[j] != "" && w[j] !~ /^(state|as|TB|TD|BT|RL|LR)$/ && !(w[j] in ids)) { ids[w[j]] = 1; cnt++ }
      }
      if (cnt > 12) print "WARN\tthe diagram at line " start " has " cnt " nodes — keep it to about 12, or leave a part out"
      if (msgs > 12) print "WARN\tthe sequence at line " start " has " msgs " messages — keep it to about 12"
    }
    !inf && /^[[:space:]]*(```|~~~)/ {
      t = $0; sub(/^[[:space:]]*/, "", t); mk = substr(t, 1, 3); inf = 1
      ism = (substr(t, 4) ~ /^[[:space:]]*mermaid([[:space:]]|$)/)
      if (ism) { blocks++; start = NR; bsec = sec; n = 0; split("", L) }
      next
    }
    inf && /^[[:space:]]*(```|~~~)/ {
      t = $0; sub(/^[[:space:]]*/, "", t)
      if (substr(t, 1, 3) == mk) { if (ism) check(); inf = 0; ism = 0; next }
    }
    inf { if (ism) L[++n] = $0; next }
    /^## / { sec = $0; sub(/[[:space:]]+$/, "", sec); sub(/\r$/, "", sec) }
    END { if (blocks > 1) print "FAIL\t" blocks " mermaid blocks — the body takes one diagram" }' "$BODY")

  if [ -n "$TITLE" ]; then
    [ "${#TITLE}" -le 70 ] || err "title is ${#TITLE} chars (max 70)"
    case "$TITLE" in *.) err "title ends with a period";; esac
    if [ "$(title_style)" = conventional ]; then
      printf '%s\n' "$TITLE" | grep -qE "^($TYPES)(\([a-z0-9._-]+\))?!?: .+" \
        || err "this repo titles commits conventionally — use 'type(scope): description'"
    fi
  fi

  [ "$FAIL" = 0 ] || exit 1
  # --ship reads this exit code, so a warning stops the ship until the line is
  # fixed or explicitly accepted.
  if [ "$WARNED" = 1 ] && [ "$ACCEPT" = 0 ]; then
    echo "lint: warnings — fix each warned line; add --accept-warnings only when every warning misreads its line"
    exit 2
  fi
  echo "lint: PR body OK"
  exit 0
fi

# The only path to GitHub: the lint result, not the model, decides whether
# anything is pushed or posted. The preflight runs again first, so every abort
# (divergence, a dirty file in the diff, a conflict on a new PR) is checked at
# ship time, and an update is linted against the PR's body as GitHub holds it
# now, which keeps an edit made since the first preflight too. The preflight
# hands its facts over in a state file rather than through the model, so the
# base, the push, the PR number and the saved body cannot be miscopied.
if [ "${1:-}" = "--ship" ]; then
  USAGE="usage: pr-preflight.sh --ship <body-file> [--title-file <file>] [--base <branch>] [--accept-warnings]"
  [ -n "${2:-}" ] || { echo "$USAGE"; exit 1; }
  BODY="$(abspath "$2")"; shift 2
  TITLEF=""; BASE_ARG=""; ACCEPT=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --title-file) [ -n "${2:-}" ] || { echo "$USAGE"; exit 1; }; TITLEF="$(abspath "$2")"; shift 2 ;;
      --base) [ -n "${2:-}" ] || { echo "$USAGE"; exit 1; }; BASE_ARG="$2"; shift 2 ;;
      --accept-warnings) ACCEPT="--accept-warnings"; shift ;;
      *) echo "$USAGE"; echo "$TITLE_HINT"; exit 1 ;;
    esac
  done
  [ -f "$BODY" ] || { echo "NOT SHIPPED: no such file: $BODY"; exit 1; }

  # Every stop prints one NOT SHIPPED line, its cause and then what to do, and
  # exits with the code for its cause: 1 the gate refused the call or the lint
  # failed, 2 the lint warned, 3 the preflight stopped, 4 the pre-push hook
  # failed, 5 the push or gh failed outside any hook. A stop that repeats the
  # last one on this body file made no progress, so its fix becomes a hand-back
  # to the user instead of another loop. The record sits beside the body file
  # and goes once the body ships.
  STOPF="$BODY.stop"; S_EXIST=""; S_KEEP=""
  stop() { # <exit> <cause> <fix> [<what makes two stops the same; default the cause>]
    local same="${4:-$2}"
    if [ -f "$STOPF" ] && [ "$(cat "$STOPF")" = "$same" ]; then
      echo "NOT SHIPPED: $2 — the same stop as the last run on this body: hand back, showing the user $BODY and the output above"
    else
      echo "NOT SHIPPED: $2 — $3"
    fi
    printf '%s' "$same" > "$STOPF" 2>/dev/null
    rm -f "$S_EXIST" "$S_KEEP"
    exit "$1"
  }

  STATE="$(mktemp "${TMPDIR:-/tmp}/pr-state.XXXXXX")"
  OUT="$(PR_SHIP_STATE="$STATE" bash "$SELF" ${BASE_ARG:+"$BASE_ARG"} 2>&1)"; RC=$?
  if [ "$RC" != 0 ]; then
    ABORT="$(printf '%s\n' "$OUT" | sed -n '/^ABORT/,$p')"
    printf '%s\n' "$ABORT"
    rm -f "$STATE"
    stop 3 "the preflight stopped, so nothing was pushed or posted" \
      "the ABORT line above names what has to change first; show it to the user" "$ABORT"
  fi
  printf '%s\n' "$OUT" | grep '^WARN'
  S_BASE=""; S_PUSH=""; S_PR=""
  while IFS=$'\t' read -r K V; do
    case "$K" in
      BASE) S_BASE="$V" ;;
      PUSH) S_PUSH="$V" ;;
      PR_NUM) S_PR="$V" ;;
      EXIST) S_EXIST="$V" ;;
      KEEP) S_KEEP="$V" ;;
    esac
  done < "$STATE"
  rm -f "$STATE"
  [ -n "$S_BASE" ] || stop 3 "the preflight reported no base" "show the user the preflight output"

  # A new PR needs a title; an update leaves the title as it is.
  if [ -n "$S_PR" ]; then
    [ -z "$TITLEF" ] || stop 1 "#$S_PR is open, and an update leaves its title as it is" "run --ship without --title-file"
  else
    [ -n "$TITLEF" ] || stop 1 "a new PR needs a title" "write it to its own mktemp file and pass --title-file <file>"
  fi

  LARGS=(--lint "$BODY")
  [ -n "$TITLEF" ] && LARGS+=(--title-file "$TITLEF")
  [ -n "$S_EXIST" ] && LARGS+=(--existing "$S_EXIST")
  [ -n "$S_KEEP" ] && LARGS+=(--keep "$S_KEEP")
  [ -n "$ACCEPT" ] && LARGS+=("$ACCEPT")
  LOUT="$(bash "$SELF" "${LARGS[@]}")"; RC=$?
  printf '%s\n' "$LOUT"
  case "$RC" in
    0) ;;
    2) stop 2 "lint warned" "fix each warned line in $BODY and run --ship again; add --accept-warnings only when every warning misreads its line" "$LOUT" ;;
    *) stop 1 "lint failed" "fix the flagged lines in $BODY and run --ship again" "$LOUT" ;;
  esac
  TITLE=""; [ -z "$TITLEF" ] || TITLE="$(read_title "$TITLEF")"

  if [ -n "$S_PUSH" ]; then
    echo "push: $S_PUSH"
    # Split on purpose: the preflight built it from a remote and a branch name,
    # and neither can hold a space. trace2 records which hook failed, if one did.
    T2="$(mktemp "${TMPDIR:-/tmp}/pr-trace.XXXXXX")"
    ( export GIT_TRACE2_PERF="$T2"; $S_PUSH ) 2>&1; RC=$?
    HOOK="$(failed_hook "$T2")"; rm -f "$T2"
    if [ "$RC" != 0 ]; then
      if [ "$HOOK" = pre-push ]; then
        stop 4 "the pre-push hook failed, output above" "fix what it flags, commit the fix, and run --ship again"
      else
        stop 5 "the push failed${HOOK:+ in the $HOOK hook}, output above" \
          "nothing in the body fixes this: run --ship once more in case the network dropped it"
      fi
    fi
  fi

  if [ -n "$S_PR" ]; then
    gh pr edit "$S_PR" --body-file "$BODY" 2>&1; RC=$?
    WHAT="updated the body of #$S_PR"
  else
    gh pr create --base "$S_BASE" --title "$TITLE" --body-file "$BODY" 2>&1; RC=$?
    WHAT="opened a PR against $S_BASE"
  fi
  [ "$RC" = 0 ] || stop 5 "gh failed${S_PUSH:+ after the push went through}, output above" \
    "run --ship once more, which skips what already went through"
  rm -f "$STOPF" "$S_EXIST" "$S_KEEP"
  echo "SHIPPED: $WHAT"
  exit 0
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
# stale remote-tracking ref. Explicit refspecs, because a bare branch name only
# updates a tracking ref the remote's configured refspec covers — never true in
# a single-branch or shallow clone. If only the base fetch succeeds, the branch
# is not on the remote; if both fail, nothing is proven, so fall back to the
# cached refs and say the report may be stale.
BASE_SPEC="+refs/heads/$BASE:refs/remotes/$REMOTE/$BASE"
HEAD_SPEC="+refs/heads/$HEAD_BRANCH:refs/remotes/$REMOTE/$HEAD_BRANCH"
HEAD_REMOTE=yes
if ! FETCH_ERR="$(git fetch --quiet "$REMOTE" "$BASE_SPEC" "$HEAD_SPEC" 2>&1)"; then
  HEAD_REMOTE=no
  FETCH_ERR="$(git fetch --quiet "$REMOTE" "$BASE_SPEC" 2>&1)" || {
    HEAD_REMOTE=cached
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
  # Both sides from `git diff --name-only`, so paths are spelled and quoted the
  # same way (status quotes paths with spaces; diff does not). --no-renames
  # lists both names of a rename, so neither side can hide the other.
  OVERLAP="$(comm -12 <(git diff --name-only --no-renames HEAD | sort -u) \
                      <(git diff --name-only --no-renames "$MB" HEAD | sort -u))"
  if [ -n "$OVERLAP" ]; then
    echo "ABORT: uncommitted changes touch files in this PR's diff — commit or stash them first:"
    printf '%s\n' "$OVERLAP" | sed 's/^/    /'
    exit 1
  fi
  echo "WARN: uncommitted local changes, none in this PR's diff — push ships commits"
  echo "      only, so proceeding; the PR will not include:"
  printf '%s\n' "$DIRTY" | sed 's/^/    /'
fi

# Compare against this branch on the remote, not whatever @{u} names: a branch
# made with `checkout -b feat origin/main` tracks the base, and a bare `git push`
# would then be refused (push.default=simple) or land on the base (=upstream).
# push -u is the default because it also repoints a wrong upstream.
RB="$REMOTE/$HEAD_BRANCH"
UP="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
PUSH="git push -u $REMOTE $HEAD_BRANCH"; UP_NOTE=""
if [ "$HEAD_REMOTE" != no ] && git rev-parse --verify --quiet "refs/remotes/$RB" >/dev/null; then
  set -- $(git rev-list --left-right --count "HEAD...refs/remotes/$RB")
  AHEAD="${1:-0}"; BEHIND="${2:-0}"
  if [ "$BEHIND" != 0 ] && [ "$AHEAD" != 0 ]; then
    echo "ABORT: $HEAD_BRANCH and $RB have diverged ($AHEAD ahead, $BEHIND behind) — local history was"
    echo "       rewritten or someone else pushed; reconcile by hand (this skill never force-pushes)."
    exit 1
  fi
  [ "$BEHIND" = 0 ] \
    || { echo "ABORT: $RB has $BEHIND commit(s) you do not — 'git pull --ff-only' first."; exit 1; }
  if [ "$UP" = "$RB" ]; then
    if [ "$AHEAD" = 0 ]; then PUSH=""; else PUSH="git push"; fi
  fi
fi
[ -n "$UP" ] && [ "$UP" != "$RB" ] \
  && UP_NOTE="upstream is $UP, not $RB — the push -u above repoints it"

# A swallowed query failure would read as "no PR open" and make the agent open a
# second PR on a branch that already has one.
# --head matches the branch name alone, so a fork's PR from a same-named branch
# (patch-1) would match too; keep only PRs whose head lives in $REMOTE's owner.
OWNER="$(git remote get-url "$REMOTE" | sed -E 's#/+$##; s#\.git$##; s#^.*[:/]([^/:]+)/[^/:]+$#\1#' \
         | tr '[:upper:]' '[:lower:]')"
if printf '%s' "$OWNER" | grep -qE '^[a-z0-9][a-z0-9-]*$'; then
  OWNER_SEL="select((.headRepositoryOwner.login | ascii_downcase) == \"$OWNER\") | "
else
  OWNER_SEL=""
fi
if ! PR="$(gh pr list --head "$HEAD_BRANCH" --state open \
           --json number,url,baseRefName,isDraft,headRepositoryOwner \
           --jq ".[] | $OWNER_SEL\"\\(.number)\\t\\(.url)\\t\\(.baseRefName)\\t\\(.isDraft)\"" 2>&1)"; then
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
if [ -n "$PUSH" ]; then
  echo "push:  $PUSH  (the ship command runs it)"
else
  echo "push:  not needed — remote is up to date"
fi
[ -z "$UP_NOTE" ] || echo "       NOTE: $UP_NOTE"
if [ -n "$PR" ]; then
  IFS=$'\t' read -r PR_NUM PR_URL PR_BASE PR_DRAFT <<<"$PR"
  echo "pr:    #$PR_NUM open  $PR_URL  base=$PR_BASE draft=$PR_DRAFT"
  [ "$PR_BASE" = "$BASE" ] \
    || echo "       NOTE: the open PR targets '$PR_BASE', you asked for '$BASE' — keep its base unless the user asked to retarget"
  # gh pr edit --body-file replaces the whole body, so what people added in
  # GitHub (a ticked box, a screenshot, `Closes #12`) is saved and listed here
  # for the new body to carry. A body that cannot be read is never overwritten.
  EXIST_FILE="$(mktemp "${TMPDIR:-/tmp}/pr-existing.XXXXXX")"
  if ! EXIST_ERR="$(gh pr view "$PR_NUM" --json body --jq .body 2>&1 >"$EXIST_FILE")"; then
    rm -f "$EXIST_FILE"
    echo "ABORT: could not read the current body of #$PR_NUM — refusing to overwrite it:"
    printf '%s\n' "$EXIST_ERR" | sed 's/^/    /'
    exit 1
  fi
  echo "existing body: $EXIST_FILE  (the ship command reads it again as it ships)"
  KEEP="$(keep_lines "$EXIST_FILE")"
  # The lint holds the new body to these lines; --ship passes it the file.
  KEEP_FILE="$(mktemp "${TMPDIR:-/tmp}/pr-keep.XXXXXX")"
  if OTHERS="$(other_people_lines "$PR_URL" "$PR_NUM" "$EXIST_FILE")"; then
    printf '%s\n' "$OTHERS" | cut -f2- | grep -v '^$' > "$KEEP_FILE"
  else
    OTHERS=""
    echo "WARN: the body's edit history did not load — lines other people typed are not"
    echo "      protected on this update, only ticked boxes, images, and closing keywords"
  fi
  if [ -n "$KEEP" ] || [ -n "$OTHERS" ]; then
    echo "keep:  lines people added — carry each into the new body verbatim:"
    [ -z "$KEEP" ] || printf '%s\n' "$KEEP" | sed 's/^/    /'
    [ -z "$OTHERS" ] || printf '%s\n' "$OTHERS" \
      | awk -F'\t' '$1 != last { print "    added by @" $1 ":"; last = $1 } { print "        " $2 }'
  else
    echo "keep:  none"
  fi
  # Whether an update has a reason to rewrite the body: the commits on this
  # branch dated after the body was last saved, pushed or not. Commit dates, so
  # a rebase counts its commits as new, which a rewrite then checks.
  SAVED="$(body_saved_at "$PR_URL" "$PR_NUM")"
  if [ -n "$SAVED" ]; then
    SINCE="$(git rev-list --count --since="$SAVED" "$MB..HEAD" 2>/dev/null)"
    if [ "${SINCE:-0}" -gt 0 ]; then
      echo "body:  last saved $SAVED; $SINCE commit(s) on this branch since — a reason to rewrite it"
    else
      echo "body:  last saved $SAVED; no commit since — rewrite it only for a change the user names (see Updates)"
    fi
  else
    echo "body:  when it was last saved did not load — judge from the body and the commits (see Updates)"
  fi
  ACTION="UPDATE the body of #$PR_NUM"
else
  echo "pr:    none open for this branch"
  ACTION="CREATE a PR against $BASE"
fi
TPL="$(find_template)"; TPLDIR="$(template_dir)"
if [ -n "$TPL" ]; then
  # gh pr create --body-file never applies the repo template, so the body
  # written here is the only one the reviewer gets. Show the shape that is
  # enforced, not the template's prose.
  echo "template: $TPL  (fill THIS shape instead of the SKILL.md template — gh does not apply it, so your body is the only one the reviewer gets)"
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

# Generated-or-not is the only classification here, because it is the only one
# that can be answered without a model of what kind of project this is: the repo
# declares it in .gitattributes, and the fallback covers only files that are
# generated in every ecosystem. Anything that would need to know what a "test"
# or a "migration" looks like in this language is left to the diff, which the
# model now reads in full.
# One predicate, three modes: names (each file's post-rename path, for
# check-attr), report (line totals), paths (generated paths plus the old side
# of a rename, so the diff command below excludes exactly what the report says
# it excludes). Declared sets arrive via ENVIRON — macOS awk rejects a newline
# inside a -v value.
CLASSIFIER='
BEGIN {
  n = split(ENVIRON["DECLARED"], d, "\n"); for (i = 1; i <= n; i++) if (d[i] != "") declared[d[i]] = 1
  n = split(ENVIRON["UNDECLARED"], d, "\n"); for (i = 1; i <= n; i++) if (d[i] != "") undeclared[d[i]] = 1
}
function clean(p) { gsub(/\/\/+/, "/", p); sub(/^\//, "", p); return p }
function generated(p,   lp) {
  if (p in declared) return 1
  if (p in undeclared) return 0
  lp = tolower(p)
  if (lp ~ /(^|\/)(node_modules|vendor|__snapshots__)\//) return 1
  if (lp ~ /(\.lock|\.lockb|-lock\.json|\.snap|\.min\.[a-z]+)$/) return 1
  return 0
}
NF >= 3 {
  path = $3; old = ""
  if (match(path, /\{[^}]* => [^}]*\}/)) {
    pre = substr(path, 1, RSTART - 1); post = substr(path, RSTART + RLENGTH)
    mid = substr(path, RSTART + 1, RLENGTH - 2); k = index(mid, " => ")
    old = clean(pre substr(mid, 1, k - 1) post); path = clean(pre substr(mid, k + 4) post)
  } else if ((k = index(path, " => ")) > 0) {
    old = substr(path, 1, k - 1); path = substr(path, k + 4)
  }
  if (MODE == "names") { print path; next }
  g = generated(path)
  if (MODE == "paths") { if (g) { print path; if (old != "") print old }; next }
  if ($1 != "-") { if (g) gen += $1 + $2; else rev += $1 + $2 }
}
END { if (MODE == "report") printf "%d %d\n", rev + 0, gen + 0 }'

# What counts as generated is the repo's call, not this script's guess: any path
# the repo marks linguist-generated or linguist-vendored in .gitattributes is
# authoritative, either way — `=true`/set adds it, `=false`/unset (`-attr`)
# overrides the fallback extension list, which covers only repos that declare
# nothing.
ATTRS="$(printf '%s\n' "$NUMSTAT" | awk -F'\t' -v MODE=names "$CLASSIFIER" \
  | git check-attr --stdin linguist-generated linguist-vendored 2>/dev/null)"
DECLARED="$(printf '%s\n' "$ATTRS" \
  | sed -nE 's/: linguist-(generated|vendored): (set|true)$//p' | sort -u)"
UNDECLARED="$(printf '%s\n' "$ATTRS" \
  | sed -nE 's/: linguist-(generated|vendored): (unset|false)$//p' | sort -u)"

echo
echo "-- commits ($REMOTE/$BASE..HEAD) --"; echo "$COMMITS" | sed 's/^/    /'
echo "-- files changed --"
printf '%s\n' "$NUMSTAT" | awk -F'\t' '{ printf "    %6s %-6s %s\n", "+"$1, "-"$2, $3 }'

read -r REV GEN <<<"$(printf '%s\n' "$NUMSTAT" \
  | DECLARED="$DECLARED" UNDECLARED="$UNDECLARED" awk -F'\t' -v MODE=report "$CLASSIFIER")"

# Exclude the generated paths from the diff the model is told to read, rather
# than printing the full diff and asking it in prose to skip them. `literal`
# keeps a path like `[id].lock` from being read as a glob; shq keeps a quote in
# a path from breaking the printed command.
shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
EXCLUDES=""
while IFS= read -r p; do
  [ -n "$p" ] && EXCLUDES="$EXCLUDES $(shq ":(exclude,literal)$p")"
done < <(printf '%s\n' "$NUMSTAT" \
  | DECLARED="$DECLARED" UNDECLARED="$UNDECLARED" awk -F'\t' -v MODE=paths "$CLASSIFIER")
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

# A new PR that cannot merge is stopped here, before anything is pushed.
# Resolving it takes a rebase or a merge, which rewrites or extends the branch,
# and that is the user's call, never this skill's. An open PR already shows its
# conflict in GitHub, so an update goes ahead and reports it.
if [ -n "$CONFLICTS" ] && [ -z "$PR" ]; then
  echo "ABORT: this branch conflicts with $REMOTE/$BASE, so a new PR could not merge."
  echo "       Resolving it takes a rebase or merge, which is the user's call. Conflicting files:"
  printf '%s\n' "$CONFLICTS" | head -20 | sed 's/^/    /'
  exit 1
fi

echo
echo "-- merge risk --"
RISK=0
if [ -n "$CONFLICTS" ]; then
  echo "    [conflict] real conflicts with $REMOTE/$BASE — name them in ## Impact:"
  printf '%s\n' "$CONFLICTS" | head -20 | sed 's/^/        /'
  RISK=1
elif [ "$MT_RC" -gt 1 ]; then
  echo "    [conflict] not checked — git merge-tree is unavailable here; say so in ## Impact"
fi
if [ "${BEHIND_BASE:-0}" -gt 0 ]; then
  echo "    [stale]    $REMOTE/$BASE is $BEHIND_BASE commit(s) ahead of your merge base — say in ## Impact that the base moved"
  RISK=1
fi
if [ -n "$DELETED" ]; then
  DEL_N="$(printf '%s\n' "$DELETED" | grep -c .)"
  echo "    [deleted]  $DEL_N file(s) removed — in ## Changes, name what used to call or read each one:"
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
echo "action: ${PUSH:+push, then }$ACTION"
if [ -n "$PR" ]; then SHIP_TITLE=""; else SHIP_TITLE=" --title-file <title-file>"; fi
echo "ship:   bash $(shq "$SELF") --ship <body-file>$SHIP_TITLE --base $(shq "$BASE")"
# --ship reads its facts here instead of trusting the model to copy them.
if [ -n "${PR_SHIP_STATE:-}" ]; then
  printf 'BASE\t%s\nPUSH\t%s\nPR_NUM\t%s\nEXIST\t%s\nKEEP\t%s\n' \
    "$BASE" "$PUSH" "${PR_NUM:-}" "${EXIST_FILE:-}" "${KEEP_FILE:-}" > "$PR_SHIP_STATE"
fi
echo "== END PREFLIGHT — read the diff, write the body, then run the ship command =="
