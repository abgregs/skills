#!/usr/bin/env bash
# test-git-create-pr.sh — repo tooling, not part of any skill.
#
# Regression cases for git/skills/git-create-pr/scripts/pr-preflight.sh: the
# lint, the preflight report, the ship gate, and the keep lines read from a
# PR body's history. Lives here, not in the skill folder, because the skills
# CLI copies a skill's whole folder to every user who installs it.
#
# Each case runs in a throwaway repo under $TMPDIR with a local bare remote and
# a stub `gh` first on PATH that logs what it is asked to do, so no case
# touches this repo, GitHub, or the user's git config.
#
# Usage: bash scripts/test-git-create-pr.sh   (exit 1 on any failing case)
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
P="${GIT_CREATE_PR_PREFLIGHT:-$REPO/git/skills/git-create-pr/scripts/pr-preflight.sh}"
EX="$REPO/git/skills/git-create-pr/examples/pr-body.md"
W="$(mktemp -d "${TMPDIR:-/tmp}/test-git-create-pr.XXXXXX")"
PASS=0; FAILS=0
trap '[ "$FAILS" = 0 ] && rm -rf "$W" || echo "kept $W for inspection"' EXIT

# Isolation from the user's git config (signing, hooks paths, templates).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

mkdir "$W/bin"
cat > "$W/bin/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "pr list") [ -n "${STUB_PR:-}" ] && printf '%b\n' "$STUB_PR"; exit 0 ;;
  "pr view") [ -n "${STUB_VIEW_FAIL:-}" ] && { echo "HTTP 502: Bad Gateway" >&2; exit 1; }
             cat "$STUB_BODY"; exit 0 ;;
  "api graphql") case "$*" in *lastEditedAt*) echo "${STUB_EDITED:-}"; exit 0 ;; esac
             [ -n "${STUB_HIST_FAIL:-}" ] && { echo "HTTP 502" >&2; exit 1; }
             if [ -n "${STUB_HIST:-}" ]; then cat "$STUB_HIST"; else echo me; fi; exit 0 ;;
  "pr create"|"pr edit")
    { printf 'gh'; printf ' %q' "$@"; printf '\n'; } >> "$GH_LOG"
    [ -n "${STUB_GH_FAIL:-}" ] && { echo "GraphQL: something broke" >&2; exit 1; }
    echo "https://github.com/o/r/pull/${STUB_NUM:-99}"; exit 0 ;;
esac
exit 0
EOF
chmod +x "$W/bin/gh"
export PATH="$W/bin:$PATH" GH_LOG="$W/gh.log"

# ---- case helpers: t runs one command; has/lacks/remote/ghcall add checks; ok reports
t() { NAME="$1"; WANT="$2"; shift 2; : > "$GH_LOG"; OUT="$("$@" 2>&1)"; RC=$?; WHY=""
      [ "$RC" = "$WANT" ] || WHY="exit $RC, want $WANT"; }
why() { WHY="${WHY:+$WHY; }$1"; }
has() { printf '%s\n' "$OUT" | grep -qE -- "$1" || why "no output matching: $1"; }
lacks() { printf '%s\n' "$OUT" | grep -qE -- "$1" && why "unexpected output: $1"; }
remote() { local got=no; git ls-remote --heads origin feat | grep -q . && got=yes
           [ "$got" = "$1" ] || why "branch on remote: $got, want $1"; }
ghcall() { if [ "$1" = none ]; then [ ! -s "$GH_LOG" ] || why "gh was called: $(cat "$GH_LOG")"
           else grep -qE -- "$1" "$GH_LOG" || why "no gh call matching: $1 (log: $(cat "$GH_LOG"))"; fi; }
ok() { if [ -z "$WHY" ]; then PASS=$((PASS + 1)); echo "PASS  $NAME"
       else FAILS=$((FAILS + 1)); echo "FAIL  $NAME — $WHY"; printf '%s\n' "$OUT" | sed 's/^/        | /'; fi; }

# repo <name> <conflict:yes|no>: a bare remote and a clone, main pushed, feat committed locally
repo() {
  local d="$W/$1"; mkdir -p "$d"; git init -q --bare "$d/origin.git"
  git clone -q "$d/origin.git" "$d/work" 2>/dev/null; cd "$d/work" || exit 1
  git checkout -q -b main; echo 1 > a.txt; git add a.txt; git commit -qm "add a"; git push -q origin main
  git checkout -q -b feat
  if [ "$2" = yes ]; then echo 2 > a.txt; git commit -qam "change a on feat"
    git checkout -q main; echo 3 > a.txt; git commit -qam "change a on main"; git push -q origin main
    git checkout -q feat
  else echo b > b.txt; git add b.txt; git commit -qm "add b"; fi
}

# ttl <title>: the title in a file of its own, as the skill writes it; prints the path
TN=0; ttl() { TN=$((TN + 1)); printf '%s\n' "$1" > "$W/title-$TN.txt"; echo "$W/title-$TN.txt"; }
# ---- bodies
sed -n '/^```markdown$/,/^```$/p' "$EX" | sed '1d;$d' > "$W/ok.md"
sed 's/^- `listOrders` accepts/- Adding `listOrders` accepts/' "$W/ok.md" > "$W/warn.md"
sed '/^## Testing/,$d' "$W/ok.md" > "$W/no-testing.md"
cat > "$W/mermaid.md" <<'EOF'
## Summary

A quick stop could land before the tap's run loop ran. The tap now reports started from inside the loop.

```mermaid
flowchart LR
  A[Tap pressed] --> B{"session.isRecording"}
  B -->|yes| C[Stop]
  B -->|no| D[Start]
```

## Changes

- `TapStateMachine.handleTap` takes `isRecording`
- `HotkeyManager` reads it from `RiverSession`

## Testing

For the reviewer:
- [ ] Run `swift test`
- [ ] Tap while the model is preparing, then tap again
EOF
sed 's/D\[Start\]/D[Start]\n  E[Generated with Claude Code]/' "$W/mermaid.md" > "$W/mermaid-prov.md"
sed 's/C\[Stop\]/C[Stop, may retry]/' "$W/mermaid.md" > "$W/mermaid-hedge.md"
{ cat "$W/ok.md"; printf '\n```bash\necho "Generated with Claude Code"\n```\n'; } > "$W/fenced-prov.md"
cat > "$W/current.md" <<'EOF'
## Summary

Old.

Closes #12

## Testing

For the reviewer:
- [x] Request `/orders?page=3` and confirm the `Deprecation` header and unchanged payload
- [ ] Another check

![checkout page](https://github.com/user-attachments/assets/abc123)
EOF
{ sed 's/^- \[ \] Request `\/orders?page=3`/- [x] Request `\/orders?page=3`/' "$W/ok.md"
  printf '\nCloses #12\n\n![checkout page](https://github.com/user-attachments/assets/abc123)\n'; } > "$W/kept.md"
sed 's/^- \[ \] Load/- [x] Load/' "$W/kept.md" > "$W/new-tick.md"
sed 's/$/\r/' "$W/current.md" > "$W/current-crlf.md"

echo "== lint"
repo lint no
t "example body lints clean" 0 bash "$P" --lint "$W/ok.md" --title-file "$(ttl 'Add cursor pagination to the orders endpoint')"; ok
t "a gerund bullet warns and exits 2" 2 bash "$P" --lint "$W/warn.md" --title-file "$(ttl 'Add cursor pagination')"; has 'opens with an -ing word'; ok
t "--accept-warnings passes a warned body" 0 bash "$P" --lint "$W/warn.md" --title-file "$(ttl 'Add cursor pagination')" --accept-warnings; ok
mkdir -p sub; t "a relative body path resolves from a subdir" 0 bash -c "cd sub && bash '$P' --lint ../../../ok.md"; ok
t "a title passed as an argument is refused, naming --title-file" 1 bash "$P" --lint "$W/ok.md" 'Add b'; has '^usage:'; has 'its own file, passed with --title-file'; ok
t "--existing without a file is a usage error" 1 bash "$P" --lint "$W/ok.md" --existing; has '^usage:'; ok
t "--existing naming a missing file fails" 1 bash "$P" --lint "$W/ok.md" --existing "$W/nope.md"; has 'no such file'; ok
t "an update that drops kept lines fails" 1 bash "$P" --lint "$W/ok.md" --existing "$W/current.md"; has 'missing.*Closes #12'; has 'missing.*user-attachments'; ok
t "an update that keeps them passes, reviewer tick included" 0 bash "$P" --lint "$W/kept.md" --existing "$W/current.md"; ok
t "the same tick without --existing fails" 1 bash "$P" --lint "$W/kept.md"; has 'ticked box in Testing'; ok
t "a box the agent ticks itself fails" 1 bash "$P" --lint "$W/new-tick.md" --existing "$W/current.md"; has 'ticked box.*Load'; ok
t "a CRLF current body matches line for line" 0 bash "$P" --lint "$W/kept.md" --existing "$W/current-crlf.md"; ok
printf 'QA: check on Intel Macs\n' > "$W/keep-extra.txt"
t "--keep fails a body without its line" 1 bash "$P" --lint "$W/ok.md" --keep "$W/keep-extra.txt"; has 'missing.*Intel Macs'; ok
{ cat "$W/ok.md"; printf '\nQA: check on Intel Macs\n'; } > "$W/ok-qa.md"
t "--keep passes a body with its line" 0 bash "$P" --lint "$W/ok-qa.md" --keep "$W/keep-extra.txt"; ok
t "mermaid labels with brackets are not placeholders" 0 bash "$P" --lint "$W/mermaid.md" --title-file "$(ttl 'Report the tap started from inside its loop')"; ok
t "provenance inside a mermaid block fails" 1 bash "$P" --lint "$W/mermaid-prov.md" --title-file "$(ttl 'Report the tap started')"; has 'attribution byline'; ok
# On macOS a bare mktemp ignores TMPDIR and writes to the per-user temp dir,
# which an agent's Bash sandbox denies; this stub fails a bare call the same way.
mkdir -p "$W/sandbox-bin"
printf '%s\n' '#!/bin/sh' 'for a; do case "$a" in -*) ;; *) exec /usr/bin/mktemp "$@" ;; esac; done' \
  'echo "mktemp: Operation not permitted" >&2; exit 1' > "$W/sandbox-bin/mktemp"; chmod +x "$W/sandbox-bin/mktemp"
t "provenance still fails where a bare mktemp is denied" 1 env PATH="$W/sandbox-bin:$PATH" bash "$P" --lint "$W/mermaid-prov.md" --title-file "$(ttl 'Report the tap started')"
has 'attribution byline'; ok
t "a hedge inside a mermaid block warns" 2 bash "$P" --lint "$W/mermaid-hedge.md" --title-file "$(ttl 'Report the tap started')"; has 'hedge word'; ok
t "provenance quoted in a bash fence stays legal" 0 bash "$P" --lint "$W/fenced-prov.md"; ok

# Every hit of a kind is named in one stop, so one rewrite clears them all.
cat > "$W/many-warn.md" <<'EOF'
## Summary

Large accounts timed out on the orders list. `listOrders` now returns one page at a time.

## Changes

- Adding a cursor to `listOrders`
- Returning a `next` link from `orders`
- `listOrders` may cap a page at 100
- `orders` might drop the total count

## Testing

For the reviewer:
- [ ] Request `/orders?cursor=abc`
- [ ] Request `/orders` with no cursor
EOF
t "every -ing bullet and every hedge warns in one stop" 2 bash "$P" --lint "$W/many-warn.md"
[ "$(printf '%s\n' "$OUT" | grep -c 'opens with an -ing word')" = 2 ] || why "want 2 -ing warnings"
[ "$(printf '%s\n' "$OUT" | grep -c 'hedge word')" = 2 ] || why "want 2 hedge warnings"; ok
cat > "$W/many-fail.md" <<'EOF'
## Summary

Large accounts timed out on the orders list. `listOrders` now returns one page at a time.

## Changes

- [Key change one]
- [Another key change]

## Testing

For the reviewer:
- [x] Ran the orders suite once
- [x] Ran it on staging
- [ ] Request `/orders` with no cursor

Co-Authored-By: First Helper <one@example.invalid>
Co-Authored-By: Second Helper <two@example.invalid>
EOF
t "every placeholder, ticked box, and trailer fails in one stop" 1 bash "$P" --lint "$W/many-fail.md"
[ "$(printf '%s\n' "$OUT" | grep -c 'unfilled placeholder')" = 2 ] || why "want 2 placeholder failures"
[ "$(printf '%s\n' "$OUT" | grep -c 'ticked box in Testing')" = 2 ] || why "want 2 ticked-box failures"
[ "$(printf '%s\n' "$OUT" | grep -c 'authorship trailer')" = 2 ] || why "want 2 trailer failures"; ok


# Verified: holds checks that ran; the label goes when nothing did.
ver_body() { # ver_body <file> <lines under Verified:>
  { printf '## Summary\n\nLarge accounts timed out on the orders list. `listOrders` now pages.\n\n## Changes\n\n- `listOrders` returns a cursor\n\n## Testing\n\nVerified:\n'
    [ -n "$2" ] && printf '%s\n' "$2"
    printf '\nFor the reviewer:\n- [ ] Request `/orders?cursor=abc`\n- [ ] Request `/orders` with no cursor\n'; } > "$1"; }
ver_body "$W/v-none.md" '- None run in this session.'
t "a Verified: whose only bullet says nothing ran fails" 1 bash "$P" --lint "$W/v-none.md"; has 'Verified: holds no check that ran'; ok
ver_body "$W/v-empty.md" ''
t "a Verified: label with nothing under it fails" 1 bash "$P" --lint "$W/v-empty.md"; has 'Verified: holds no check that ran'; ok
ver_body "$W/v-caveat.md" '- `pnpm test apps/api/orders`: 48 passed; the staging load test did not run'
t "a real result with a caveat passes" 0 bash "$P" --lint "$W/v-caveat.md"; ok

# Impact holds what a reviewer must weigh; a line saying there is nothing warns,
# since the section's absence already says it. The phrases are the recorded misses.
CHG='- `listOrders` returns a cursor'
imp_body() { # imp_body <file> <Impact lines> [<Changes bullet>]
  printf '## Summary\n\nLarge accounts timed out on the orders list. `listOrders` now pages.\n\n## Changes\n\n%s\n\n## Impact\n\n%s\n\n## Testing\n\n- [ ] Request `/orders?cursor=abc`\n- [ ] Request `/orders` with no cursor\n' \
    "${3:-$CHG}" "$2" > "$1"; }
imp_body "$W/i-none.md" 'User-visible text only: the picker hints and the Homebrew caveat show new sizes. No behavior changes.'
t "an Impact that says there is nothing to weigh warns" 2 bash "$P" --lint "$W/i-none.md"; has 'Impact line says the change carries nothing to weigh'; ok
imp_body "$W/i-mixed.md" "$(printf '%s\n' '- Clients that read every row must now follow the cursor.' '- Only user-visible strings change in the export dialog.')"
t "each Impact line saying nothing warns, and a consequence beside it does not" 2 bash "$P" --lint "$W/i-mixed.md"
[ "$(printf '%s\n' "$OUT" | grep -c 'Impact line says')" = 1 ] || why "want 1 Impact warning"; has 'Only user-visible strings change'; ok
imp_body "$W/i-weigh.md" 'Clients that read every row must now follow the cursor; the first page holds 50.'
t "an Impact that names a consequence passes" 0 bash "$P" --lint "$W/i-weigh.md"; ok
imp_body "$W/i-changes.md" 'Clients that read every row must now follow the cursor.' '- `listOrders` returns a cursor; no API changes for a caller that passes none'
t "the phrase outside Impact passes" 0 bash "$P" --lint "$W/i-changes.md"; ok

# The title crosses as a file: one line, as typed.
: > "$W/title-empty.txt"; printf 'First line\nSecond line\n' > "$W/title-two.txt"
t "an empty title file fails" 1 bash "$P" --lint "$W/ok.md" --title-file "$W/title-empty.txt"; has 'title file is empty'; ok
t "a title file of two lines fails" 1 bash "$P" --lint "$W/ok.md" --title-file "$W/title-two.txt"; has 'holds 2 lines'; ok

# Diagram mechanics: the two diagrams from evidence 0003 and 0004 must pass.
diagram_body() { # diagram_body <file> <mermaid text> [section the block sits under]
  { printf '## Summary\n\nA quick stop could land before the run loop ran. The tap now reports from inside it.\n\n'
    [ -n "${3:-}" ] && printf '## Changes\n\n- `startTap` reports from inside the loop\n\n'
    printf '```mermaid\n%s\n```\n\n' "$2"
    [ -z "${3:-}" ] && printf '## Changes\n\n- `startTap` reports from inside the loop\n\n'
    printf '## Testing\n\nFor the reviewer:\n- [ ] Run `swift test`\n- [ ] Press the hotkey in the built app\n'; } > "$1"; }
diagram_body "$W/d-0003.md" 'flowchart TD
    A["startEngine"] --> B["selectDevice"]
    B -->|"Bluetooth default and built-in present"| C["built-in microphone"]
    B -->|"otherwise"| D["default input"]
    C --> E["startUnit: pin device, then initialise"]
    D --> E
    E --> F["captureInputProc renders buffers"]
    G["HAL listeners: default input, device list, sample rate, liveness"] --> H["handleDeviceChange"]
    H -->|"different device or new rate"| I["stopUnit, then startUnit"]
    H -->|"same device, same rate"| J["no restart"]'
diagram_body "$W/d-0004.md" 'sequenceDiagram
    participant M as Main actor
    participant T as com.river.eventtap thread
    M->>T: thread.start()
    T->>T: CGEvent.tapCreate, CFRunLoopAddSource
    T->>T: CFRunLoopPerformBlock(resume)
    T->>T: CFRunLoopRun()
    T-->>M: resume(RunningTap)
    M->>M: set tap and tapRunLoop
    M->>T: stopTap, CFRunLoopStop'
t "the 0003 flowchart passes the diagram checks" 0 bash "$P" --lint "$W/d-0003.md"; ok
t "the 0004 sequence passes the diagram checks" 0 bash "$P" --lint "$W/d-0004.md"; ok
{ cat "$W/d-0004.md"; printf '\n```mermaid\nflowchart LR\n  A --> B\n```\n'; } > "$W/d-two.md"
t "a second mermaid block fails" 1 bash "$P" --lint "$W/d-two.md"; has '2 mermaid blocks'; ok
diagram_body "$W/d-placed.md" 'flowchart LR
  A --> B' changes
t "a mermaid block outside Summary fails" 1 bash "$P" --lint "$W/d-placed.md"; has 'sits under ## Changes'; ok
diagram_body "$W/d-type.md" 'graph TD
  A --> B'
t "a diagram type outside the three fails" 1 bash "$P" --lint "$W/d-type.md"; has 'is a graph'; ok
diagram_body "$W/d-big.md" 'flowchart LR
  A --> B --> C --> D --> E --> F --> G
  G --> H --> I --> J --> K --> L --> M'
t "a flowchart past 12 nodes warns" 2 bash "$P" --lint "$W/d-big.md"; has 'has 13 nodes'; ok
diagram_body "$W/d-quote.md" 'flowchart LR
  A[parse(input)] --> B["fmt(n)"]'
t "an unquoted label with punctuation warns" 2 bash "$P" --lint "$W/d-quote.md"; has 'needs double quotes'; ok
t "a backtick title passes untouched" 0 bash "$P" --lint "$W/mermaid.md" --title-file "$(ttl 'Handle `null` in parse')"; ok

echo "== preflight report"
repo report no
t "a new PR: push, CREATE, and a ship line with a title slot" 0 bash "$P" main
has '^push:  git push -u origin feat'; has '^action: push, then CREATE a PR against main'; has "^ship: .*--ship <body-file> --title-file <title-file> --base 'main'"; ok
repo conflict yes
t "a new PR that conflicts aborts before any action line" 1 bash "$P" main; has '^ABORT: this branch conflicts'; lacks '^action:'; ok
export STUB_PR='7\thttps://github.com/o/r/pull/7\tmain\tfalse' STUB_BODY="$W/current.md" STUB_NUM=7
t "an update with a conflict reports it, keeps, and ships without a title" 0 bash "$P" main
has '\[conflict\].*name them in ## Impact'; has '\[stale\].*say in ## Impact that the base moved'; has '^keep:'; has 'Closes #12'; has '^action: push, then UPDATE the body of #7'; has '^ship: .*--ship <body-file> --base'; lacks 'title-file'; ok
STUB_EDITED=2000-01-01T00:00:00Z t "an update reports the commits since the body was last saved" 0 bash "$P" main
has '^body:  last saved 2000-01-01T00:00:00Z; 1 commit\(s\) on this branch since — a reason to rewrite it'; ok
STUB_EDITED=2099-01-01T00:00:00Z t "with no commit since, the report says to rewrite only for a named change" 0 bash "$P" main
has '^body:  last saved 2099-01-01T00:00:00Z; no commit since — rewrite it only for a change the user names'; ok
t "a save time that does not load says to judge from the body" 0 bash "$P" main; has '^body:  when it was last saved did not load'; ok
STUB_VIEW_FAIL=1 t "an unreadable current body aborts the update" 1 bash "$P" main; has 'refusing to overwrite'; ok
unset STUB_PR STUB_BODY STUB_NUM
repo deleted no
git rm -q a.txt; git commit -qm "drop a"
t "a deleted file says what the body owes it, without guessing at callers" 0 bash "$P" main
has '\[deleted\]  1 file\(s\) removed — in ## Changes, name what used to call or read each one'; has '^        a\.txt$'; lacks 'break on merge'; ok

echo "== ship gate"
repo ship no
t "a new PR without a title is refused" 1 bash "$P" --ship "$W/ok.md" --base main; has 'needs a title'; remote no; ghcall none; ok
t "a failed lint pushes and posts nothing" 1 bash "$P" --ship "$W/no-testing.md" --title-file "$(ttl 'Add b')" --base main; has 'NOT SHIPPED: lint failed'; remote no; ghcall none; ok
t "a lint warning pushes and posts nothing" 2 bash "$P" --ship "$W/warn.md" --title-file "$(ttl 'Add b')" --base main; has 'NOT SHIPPED: lint warned'; remote no; ghcall none; ok
STUB_GH_FAIL=1 t "gh failing after the push exits 5 and says the branch went up" 5 bash "$P" --ship "$W/ok.md" --title-file "$(ttl 'Add b')" --base main
has '^NOT SHIPPED: gh failed after the push went through'; remote yes; ghcall 'pr create'; ok
git push -q origin --delete feat; git branch -q --unset-upstream
printf '%s\n' "Don't page \`orders\` by \$offset" > "$W/title-quotes.txt"
t "a clean body ships: push, then gh pr create with the title intact" 0 bash -c "cd sub 2>/dev/null || mkdir sub && cd sub; bash '$P' --ship ../../../ok.md --title-file '$W/title-quotes.txt' --base main"
has '^SHIPPED: opened a PR against main'; remote yes; ghcall "pr create --base main --title Don\\\\'t\\\\ page\\\\ \\\\\`orders\\\\\`\\\\ by\\\\ \\\\\\\$offset"; ok
repo ship-conflict yes
t "a conflict stops the ship before the push, with exit 3" 3 bash "$P" --ship "$W/ok.md" --title-file "$(ttl 'Change a')" --base main; has '^NOT SHIPPED: the preflight stopped'; remote no; ghcall none; ok
repo ship-update no
git push -q -u origin feat
export STUB_PR='7\thttps://github.com/o/r/pull/7\tmain\tfalse' STUB_BODY="$W/ship-current.md" STUB_NUM=7
cp "$W/current.md" "$W/ship-current.md"
t "an update with a title is refused" 1 bash "$P" --ship "$W/kept.md" --title-file "$(ttl 'A title')" --base main; has 'leaves its title as it is'; ghcall none; ok
t "an update that drops kept lines posts nothing" 1 bash "$P" --ship "$W/ok.md" --base main; has 'missing.*Closes #12'; ghcall none; ok
t "an update that keeps them edits #7 with no push" 0 bash "$P" --ship "$W/kept.md" --base main; lacks '^push:'; ghcall 'pr edit 7 --body-file'; ok
printf '\n![late screenshot](https://github.com/user-attachments/assets/late-1)\n' >> "$W/ship-current.md"
t "a screenshot added after the preflight stops the update" 1 bash "$P" --ship "$W/kept.md" --base main; has 'missing.*late-1'; ghcall none; ok
unset STUB_PR STUB_BODY STUB_NUM
repo ship-hook no
printf '#!/bin/sh\necho "pre-push: format check failed in b.txt" >&2\nexit 1\n' > .git/hooks/pre-push; chmod +x .git/hooks/pre-push
t "a failing pre-push hook exits 4, shows its output, and posts nothing" 4 bash "$P" --ship "$W/ok.md" --title-file "$(ttl 'Add b')" --base main
has 'pre-push: format check failed'; has '^NOT SHIPPED: the pre-push hook failed'; remote no; ghcall none; ok
t "the same pre-push failure again hands back to the user" 4 bash "$P" --ship "$W/ok.md" --title-file "$(ttl 'Add b')" --base main
has '^NOT SHIPPED: the pre-push hook failed.* — the same stop as the last run on this body: hand back'; ok
repo ship-refused no
printf '#!/bin/sh\necho "remote: pushes are closed" >&2\nexit 1\n' > ../origin.git/hooks/pre-receive; chmod +x ../origin.git/hooks/pre-receive
t "a push the remote refuses exits 5, apart from the pre-push hook" 5 bash "$P" --ship "$W/ok.md" --title-file "$(ttl 'Add b')" --base main
has 'pushes are closed'; has '^NOT SHIPPED: the push failed, output above'; remote no; ghcall none; ok
repo ship-repeat no
cp "$W/warn.md" "$W/repeat.md"
t "a lint stop on a body is a fix the first time" 2 bash "$P" --ship "$W/repeat.md" --title-file "$(ttl 'Add b')" --base main; lacks 'hand back'; ok
t "the identical lint stop on the same body hands back" 2 bash "$P" --ship "$W/repeat.md" --title-file "$(ttl 'Add b')" --base main
has '^NOT SHIPPED: lint warned — the same stop as the last run on this body: hand back'; ok
t "a body that ships clears its stop record" 0 bash "$P" --ship "$W/repeat.md" --title-file "$(ttl 'Add b')" --base main --accept-warnings
[ -e "$W/repeat.md.stop" ] && why "repeat.md.stop is still there"; ghcall 'pr create'; ok


echo "== repo templates and generated files"
repo tpl no
mkdir .github
printf '%s\n' '## What changed' '' '<!-- describe the change -->' '' '## How to test' '' '- [ ] I ran the test suite' > .github/pull_request_template.md
printf '%s\n' '## What changed' '' '`b.txt` holds the new value.' '' '## How to test' '' '- [ ] I ran the test suite' > "$W/tpl-good.md"
printf '%s\n' '## What changed' '' '`b.txt` holds the new value.' '' '## How to test' '' '- [ ] Open `b.txt`' > "$W/tpl-nobox.md"
t "a body in the repo template's shape passes" 0 bash "$P" --lint "$W/tpl-good.md"; ok
t "a body in the skill's own shape fails on each heading and item the template has" 1 bash "$P" --lint "$W/ok.md"
has 'section missing: ## What changed'; has 'section missing: ## How to test'; has 'checklist item missing: I ran the test suite'; ok
t "the template's checklist item is required" 1 bash "$P" --lint "$W/tpl-nobox.md"; has 'checklist item missing: I ran the test suite'; ok
t "the report shows the template's shape, not its prose" 0 bash "$P" main
has '^template: \.github/pull_request_template\.md'; has '^    ## What changed$'; has '^    - \[ \] I ran the test suite$'; lacks 'describe the change'; ok
repo tpldir no
mkdir -p .github/PULL_REQUEST_TEMPLATE
printf '%s\n' '## Bug' '' '## Repro steps' > .github/PULL_REQUEST_TEMPLATE/bug.md
printf '%s\n' '## Feature' '' '## Rollout' > .github/PULL_REQUEST_TEMPLATE/feature.md
printf '%s\n' '## Feature' '' '`b.txt` holds the new value.' '' '## Rollout' '' 'Ships with the next release.' > "$W/tpl-feature.md"
printf '%s\n' '## Feature' '' '`b.txt` holds the new value.' > "$W/tpl-half.md"
t "with several templates, a body that matches one passes" 0 bash "$P" --lint "$W/tpl-feature.md"; ok
t "a body short of its closest template fails, naming that template" 1 bash "$P" --lint "$W/tpl-half.md"
has 'closest repo template \(\.github/PULL_REQUEST_TEMPLATE/feature\.md\) section missing: ## Rollout'; ok
t "the report lists the templates and says none applies by itself" 0 bash "$P" main
has '^template: several in \.github/PULL_REQUEST_TEMPLATE'; has '^    feature\.md$'; ok
repo gen no
printf '%s\n' 'dist/** linguist-generated' 'yarn.lock -linguist-generated' > .gitattributes
mkdir dist; seq 1 300 > dist/bundle.js; seq 1 200 > package-lock.json; seq 1 50 > yarn.lock
git add .gitattributes dist package-lock.json yarn.lock; git commit -qm "add the bundle"
t "generated paths, declared or by name, are left out of the diff to read" 0 bash "$P" main
has '^reading: 53 reviewable lines, 500 generated'
has "^diff: .*':\(exclude,literal\)dist/bundle\.js' ':\(exclude,literal\)package-lock\.json'"
lacks 'exclude,literal\)yarn\.lock'; ok

echo "== the prose states what the lint checks"
# SKILL.md and the README tell the agent the lint's limits before it writes, so a
# limit changed in one place and not the other would send the agent into a stop
# it was told to avoid. Each case reads the limit from the prose and drives the
# lint with it.
SK="$REPO/git/skills/git-create-pr/SKILL.md"; RD="$REPO/git/skills/git-create-pr/README.md"
repo prose no
prose_body() { # prose_body <file> <Changes bullets, one per line> [Testing items, one per line]
  { printf '## Summary\n\nLarge accounts timed out on the orders list. `listOrders` now pages.\n\n## Changes\n\n'
    printf '%s\n' "$2" | sed 's/^/- /'
    printf '\n## Testing\n\nFor the reviewer:\n'
    printf '%s\n' "${3:-Request \`/orders?cursor=abc\`
Request \`/orders\` with no cursor}" | sed 's/^/- [ ] /'; } > "$1"; }
HEDGES="$(sed -nE 's/.*no hedges \(([^)]*)\).*/\1/p' "$SK" | tr -d ' ' | tr ',' '\n')"
prose_body "$W/p-hedge.md" "$(printf '%s\n' "$HEDGES" | sed 's/.*/`listOrders` & return a cursor/')"
t "each hedge SKILL.md names draws the lint's hedge warning" 2 bash "$P" --lint "$W/p-hedge.md"
[ "$(printf '%s\n' "$OUT" | grep -c 'hedge word')" = "$(printf '%s\n' "$HEDGES" | grep -c .)" ] || why "SKILL.md names $(printf '%s' "$HEDGES" | tr '\n' ' ')but the lint warned on fewer"; ok
VAGUE="$(sed -nE 's/.*no vague openers \(([^)]*)\).*/\1/p' "$SK" | sed 's/, /\n/g')"
prose_body "$W/p-vague.md" "$(printf '%s\n' "$VAGUE" | sed 's/.*/& `listOrders`/')"
t "each vague opener SKILL.md names draws the lint's warning" 2 bash "$P" --lint "$W/p-vague.md"
[ "$(printf '%s\n' "$OUT" | grep -c 'vague opener')" = "$(printf '%s\n' "$VAGUE" | grep -c .)" ] || why "SKILL.md names $(printf '%s' "$VAGUE" | tr '\n' ',') but the lint warned on fewer"; ok
TMAX="$(sed -nE 's/^([0-9]+) characters at most, imperative.*/\1/p' "$SK")"
grep -q "$TMAX characters at most" "$RD" || why "README does not state the $TMAX-character title limit"
t "a title at the limit SKILL.md states passes" 0 bash "$P" --lint "$W/ok.md" --title-file "$(ttl "$(printf "%${TMAX}s" | tr ' ' a)")"; ok
t "a title one past it fails" 1 bash "$P" --lint "$W/ok.md" --title-file "$(ttl "$(printf "%$((TMAX + 1))s" | tr ' ' a)")"; has "max $TMAX"; ok
NMAX="$(sed -nE 's/.*about ([0-9]+) nodes or messages at most.*/\1/p' "$SK")"
grep -q "about $NMAX nodes" "$RD" || why "README does not state the $NMAX-node diagram limit"
chain() { local i out="A0"; for i in $(seq 1 $(($1 - 1))); do out="$out --> A$i"; done; printf 'flowchart LR\n  %s' "$out"; }
diagram_body "$W/p-nodes-ok.md" "$(chain "$NMAX")"
t "a diagram at the node limit SKILL.md states passes" 0 bash "$P" --lint "$W/p-nodes-ok.md"; ok
diagram_body "$W/p-nodes-over.md" "$(chain $((NMAX + 1)))"
t "a diagram one node past it warns" 2 bash "$P" --lint "$W/p-nodes-over.md"; has "has $((NMAX + 1)) nodes"; ok
for TY in $(sed -nE 's/.*a `([a-zA-Z-]+)`, `([a-zA-Z-]+)`, or `([a-zA-Z0-9-]+)`, about.*/\1 \2 \3/p' "$SK"); do
  case "$TY" in sequenceDiagram) D='sequenceDiagram
  A->>B: call' ;; *) D="$TY
  A --> B" ;; esac
  diagram_body "$W/p-type.md" "$D"
  t "the $TY type SKILL.md allows passes" 0 bash "$P" --lint "$W/p-type.md"; ok
done
IMIN="$(sed -nE 's/.*at least ([a-z0-9]+) items in Testing.*/\1/p' "$SK" | sed 's/^two$/2/; s/^three$/3/')"
prose_body "$W/p-items.md" '`listOrders` returns a cursor' "$(seq 1 $((IMIN - 1)) | sed 's/.*/Request `\/orders` with case &/')"
t "Testing one item short of the minimum SKILL.md states fails" 1 bash "$P" --lint "$W/p-items.md"; has "Testing needs $IMIN\+ items"; ok

echo "== keep lines from the body's history"
repo history no
git push -q -u origin feat
RS="$(printf '\036')"
v1="$(cat "$W/ok.md")"
v2="$v1
QA: check on Intel Macs
Temporary note from review"
v3="$v1
QA: check on Intel Macs
My own note"
printf 'me\n%sme\n%s\n%sreviewer\n%s\n%sme\n%s\n' "$RS" "$v1" "$RS" "$v2" "$RS" "$v3" > "$W/hist"
printf '%s\n' "$v3" > "$W/hist-current.md"
export STUB_PR='7\thttps://github.com/o/r/pull/7\tmain\tfalse' STUB_BODY="$W/hist-current.md" STUB_NUM=7 STUB_HIST="$W/hist"
t "a line another login added, still in the body, is kept" 0 bash "$P" main
has 'added by @reviewer:'; has 'QA: check on Intel Macs'; lacks 'Temporary note'; lacks 'My own note'; ok
t "an update without that line posts nothing" 1 bash "$P" --ship "$W/ok.md" --base main; has 'missing.*Intel Macs'; ghcall none; ok
{ cat "$W/ok.md"; printf '\nQA: check on Intel Macs\n'; } > "$W/hist-kept.md"
t "an update with it ships; the user's own line is left to judgment" 0 bash "$P" --ship "$W/hist-kept.md" --base main; ghcall 'pr edit 7'; ok
STUB_HIST_FAIL=1 t "a history that does not load warns and still protects kept shapes" 0 bash "$P" main; has '^WARN: the body.s edit history did not load'; ok
unset STUB_PR STUB_BODY STUB_NUM STUB_HIST

echo
echo "$PASS passed, $FAILS failed"
[ "$FAILS" = 0 ]
