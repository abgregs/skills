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
P="$REPO/git/skills/git-create-pr/scripts/pr-preflight.sh"
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
  "api graphql") [ -n "${STUB_HIST_FAIL:-}" ] && { echo "HTTP 502" >&2; exit 1; }
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
t "example body lints clean" 0 bash "$P" --lint "$W/ok.md" 'Add cursor pagination to the orders endpoint'; ok
t "a gerund bullet warns and exits 2" 2 bash "$P" --lint "$W/warn.md" 'Add cursor pagination'; has 'opens with an -ing word'; ok
t "--accept-warnings passes a warned body" 0 bash "$P" --lint "$W/warn.md" 'Add cursor pagination' --accept-warnings; ok
mkdir -p sub; t "a relative body path resolves from a subdir" 0 bash -c "cd sub && bash '$P' --lint ../../../ok.md"; ok
t "two titles is a usage error" 1 bash "$P" --lint "$W/ok.md" a b; has '^usage:'; ok
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
t "mermaid labels with brackets are not placeholders" 0 bash "$P" --lint "$W/mermaid.md" 'Report the tap started from inside its loop'; ok
t "provenance inside a mermaid block fails" 1 bash "$P" --lint "$W/mermaid-prov.md" 'Report the tap started'; has 'attribution byline'; ok
t "a hedge inside a mermaid block warns" 2 bash "$P" --lint "$W/mermaid-hedge.md" 'Report the tap started'; has 'hedge word'; ok
t "provenance quoted in a bash fence stays legal" 0 bash "$P" --lint "$W/fenced-prov.md"; ok
t "a backtick title passes untouched" 0 bash "$P" --lint "$W/mermaid.md" 'Handle `null` in parse'; ok

echo "== preflight report"
repo report no
t "a new PR: push, CREATE, and a ship line with a title slot" 0 bash "$P" main
has '^push:  git push -u origin feat'; has '^action: push, then CREATE a PR against main'; has "^ship: .*--ship <body-file> '<title>' --base 'main'"; ok
repo conflict yes
t "a new PR that conflicts aborts before any action line" 1 bash "$P" main; has '^ABORT: this branch conflicts'; lacks '^action:'; ok
export STUB_PR='7\thttps://github.com/o/r/pull/7\tmain\tfalse' STUB_BODY="$W/current.md" STUB_NUM=7
t "an update with a conflict reports it, keeps, and ships without a title" 0 bash "$P" main
has '\[conflict\].*name them in ## Impact'; has '^keep:'; has 'Closes #12'; has '^action: push, then UPDATE the body of #7'; has '^ship: .*--ship <body-file> --base'; lacks "'<title>'"; ok
STUB_VIEW_FAIL=1 t "an unreadable current body aborts the update" 1 bash "$P" main; has 'refusing to overwrite'; ok
unset STUB_PR STUB_BODY STUB_NUM

echo "== ship gate"
repo ship no
t "a new PR without a title is refused" 1 bash "$P" --ship "$W/ok.md" --base main; has 'needs a title'; remote no; ghcall none; ok
t "a failed lint pushes and posts nothing" 1 bash "$P" --ship "$W/no-testing.md" 'Add b' --base main; has 'NOT SHIPPED: lint failed'; remote no; ghcall none; ok
t "a lint warning pushes and posts nothing" 2 bash "$P" --ship "$W/warn.md" 'Add b' --base main; has 'NOT SHIPPED: lint warned'; remote no; ghcall none; ok
STUB_GH_FAIL=1 t "gh failing after the push says the branch went up" 1 bash "$P" --ship "$W/ok.md" 'Add b' --base main
has 'gh failed after the push went through'; remote yes; ghcall 'pr create'; ok
git push -q origin --delete feat; git branch -q --unset-upstream
t "a clean body ships: push, then gh pr create with the title intact" 0 bash -c "cd sub 2>/dev/null || mkdir sub && cd sub; bash '$P' --ship ../../../ok.md 'Don'\''t page \`orders\` by offset' --base main"
has '^SHIPPED: opened a PR against main'; remote yes; ghcall "pr create --base main --title Don\\\\'t\\\\ page\\\\ \\\\\`orders\\\\\`\\\\ by\\\\ offset"; ok
repo ship-conflict yes
t "a conflict stops the ship before the push" 1 bash "$P" --ship "$W/ok.md" 'Change a' --base main; has 'NOT SHIPPED: the preflight stopped'; remote no; ghcall none; ok
repo ship-update no
git push -q -u origin feat
export STUB_PR='7\thttps://github.com/o/r/pull/7\tmain\tfalse' STUB_BODY="$W/ship-current.md" STUB_NUM=7
cp "$W/current.md" "$W/ship-current.md"
t "an update with a title is refused" 1 bash "$P" --ship "$W/kept.md" 'A title' --base main; has 'leaves its title as it is'; ghcall none; ok
t "an update that drops kept lines posts nothing" 1 bash "$P" --ship "$W/ok.md" --base main; has 'missing.*Closes #12'; ghcall none; ok
t "an update that keeps them edits #7 with no push" 0 bash "$P" --ship "$W/kept.md" --base main; lacks '^push:'; ghcall 'pr edit 7 --body-file'; ok
printf '\n![late screenshot](https://github.com/user-attachments/assets/late-1)\n' >> "$W/ship-current.md"
t "a screenshot added after the preflight stops the update" 1 bash "$P" --ship "$W/kept.md" --base main; has 'missing.*late-1'; ghcall none; ok
unset STUB_PR STUB_BODY STUB_NUM
repo ship-hook no
printf '#!/bin/sh\necho "pre-push: format check failed in b.txt" >&2\nexit 1\n' > .git/hooks/pre-push; chmod +x .git/hooks/pre-push
t "a failing pre-push hook shows its output and posts nothing" 1 bash "$P" --ship "$W/ok.md" 'Add b' --base main
has 'pre-push: format check failed'; has 'NOT SHIPPED: push failed'; remote no; ghcall none; ok

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
