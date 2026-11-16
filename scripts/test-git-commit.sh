#!/usr/bin/env bash
# test-git-commit.sh — repo tooling, not part of any skill.
#
# Regression cases for git/skills/git-commit/scripts/commit-preflight.sh: the
# lint, the --commit gate and each of its stops, and the preflight report.
# Lives here, not in the skill folder, because the skills CLI copies a skill's
# whole folder to every user who installs it.
#
# Each case runs in a throwaway repo under $TMPDIR, so no case touches this
# repo or the user's git config. GIT_COMMIT_PREFLIGHT points the suite at
# another copy of the script, so a deliberately broken copy can show which
# cases turn red without editing the real one.
#
# Usage: bash scripts/test-git-commit.sh   (exit 1 on any failing case)
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
P="${GIT_COMMIT_PREFLIGHT:-$REPO/git/skills/git-commit/scripts/commit-preflight.sh}"
W="$(mktemp -d "${TMPDIR:-/tmp}/test-git-commit.XXXXXX")"
PASS=0; FAILS=0
trap '[ "$FAILS" = 0 ] && rm -rf "$W" || echo "kept $W for inspection"' EXIT

# Isolation from the user's git config (signing, hooks paths, templates).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

# ---- case helpers: t runs one command; the others add checks; ok reports
t() { NAME="$1"; WANT="$2"; shift 2; OUT="$("$@" 2>&1)"; RC=$?; WHY=""
      [ "$RC" = "$WANT" ] || WHY="exit $RC, want $WANT"; }
why() { WHY="${WHY:+$WHY; }$1"; }
has() { printf '%s\n' "$OUT" | grep -qE -- "$1" || why "no output matching: $1"; }
lacks() { printf '%s\n' "$OUT" | grep -qE -- "$1" && why "unexpected output: $1"; }
head_is() { local s; s="$(git log -1 --format=%s)"; [ "$s" = "$1" ] || why "HEAD is '$s', want '$1'"; }
in_head() { git show --name-only --format= HEAD | grep -qx "$1" || why "$1 not in HEAD"; }
not_in_head() { git show --name-only --format= HEAD | grep -qx "$1" && why "$1 is in HEAD"; }
index_clean() { git diff --cached --quiet || why "index holds: $(git diff --cached --name-only | tr '\n' ' ')"; }
staged() { git diff --cached --name-only | grep -qx "$1" || why "$1 is not staged"; }
ok() { if [ -z "$WHY" ]; then PASS=$((PASS + 1)); echo "PASS  $NAME"
       else FAILS=$((FAILS + 1)); echo "FAIL  $NAME — $WHY"; printf '%s\n' "$OUT" | sed 's/^/        | /'; fi; }

# repo <name> [subject...]: a fresh repo with tracked a.txt and b.txt, whose
# history holds the given subjects (by default one ASCII subject)
repo() {
  local d="$W/$1"; shift; mkdir -p "$d"; cd "$d" || exit 1; git init -q -b main
  [ $# -gt 0 ] || set -- "chore: start"
  echo a > a.txt; echo b > b.txt; git add a.txt b.txt
  local s; for s in "$@"; do echo "$s" >> log.txt; git add log.txt; git commit -qm "$s"; done
}
# m <name> <line>...: a message file under $W, one argument per line
m() { local f="$W/$1"; shift; printf '%s\n' "$@" > "$f"; }
pad() { printf "%${1}s" "" | tr ' ' a; }
commitlint() { echo "module.exports = { extends: ['@commitlint/config-conventional'] };" > commitlint.config.js; }

# ---- messages
m ok.txt 'feat(ui): add dark mode toggle'
m ok2.txt 'fix(ui): keep the toggle state'
m amend.txt 'fix(ui): keep the toggle state on reload'
m len72.txt "fix(x): $(pad 64)"
m len73.txt "fix(x): $(pad 65)"
m fmt.txt 'updated the toggle'
m brackets.txt 'fix(ui): handle the toggle [again]'
m emoji.txt 'feat(ui): add dark mode toggle ✨'
m gitmoji.txt '✨ add dark mode toggle'
m plain.txt 'Fix login redirect'
m ticket.txt '[WID-5] fix login redirect'
m docswhy.txt 'docs(readme): fix the install path' '' '- Why: users hit a 404'
m whysecond.txt 'fix(api): retry the upload' '' '- `upload` retries twice' '- Why: the CDN drops 1 in 50 requests'
m trailer.txt 'fix(api): retry the upload' '' '- `upload` retries twice' '' 'Co-Authored-By: Someone <someone@example.invalid>'
m seven.txt 'feat(api): add seven endpoints' '' '- one' '- two' '- three' '- four' '- five' '- six' '- seven'
m ing.txt 'fix(api): retry the upload' '' '- Adding a retry to `upload`'
m noblank.txt 'fix(api): retry the upload' '- `upload` retries twice'
m subject.txt 'fix(names): split initials on any whitespace run' '' '- `initials` uses `split()`, so repeated spaces no longer raise IndexError' \
  '- `test_double_space` covers a name with two spaces' '- `order_total_cents` replaces `order_total`' '- `TokenStore` drops `refreshAll`'
m command.txt 'fix(names): split initials on any whitespace run' '' '- `initials` uses `split()`, so repeated spaces no longer raise IndexError' '- Add `test_double_space`'
m passive.txt 'fix(session): read recording state from the session' '' '- `isRecording` is set by `Session`' '- `refreshAll` is no longer called'
m whypassive.txt 'fix(billing): return order total in cents' '' '- Why: receipts showed 0.12 for a 12.00 order' '  as the total was divided by 100 twice' '- `order_total_cents` returns cents'
m state.txt 'refactor(report): split render_text' '' '- `render_text` formats the rows, and the output is unchanged'
m hook.txt 'fix(ui): keep the toggle state on resize'
m warn2.txt 'fix(api): retry the upload twice' '' '- Adding a second retry to `upload`'
m keyless.txt 'fix(auth): expire tokens on password change'
m keyed.txt 'fix(auth): expire tokens on password change WID-12'

echo "== lint: the skill's own format, in a repo with ASCII subjects and no enforcer"
repo lint
t "a conventional subject passes" 0 bash "$P" --lint "$W/ok.txt"; has '^lint: message OK'; ok
t "a 72-character subject passes" 0 bash "$P" --lint "$W/len72.txt"; ok
t "a 73-character subject fails" 1 bash "$P" --lint "$W/len73.txt"; has 'subject is 73 chars \(max 72\)'; ok
t "a subject outside type(scope) fails" 1 bash "$P" --lint "$W/fmt.txt"; has "must match 'type\(scope\): description'"; ok
t "brackets in the description fail" 1 bash "$P" --lint "$W/brackets.txt"; has 'parentheses/brackets'; ok
t "an emoji fails where the repo's subjects are ASCII" 1 bash "$P" --lint "$W/emoji.txt"; has 'non-ASCII characters'; ok
t "a docs commit with Why: fails" 1 bash "$P" --lint "$W/docswhy.txt"; has 'a docs commit takes no Why:'; ok
t "a Why: that is not the first bullet fails" 1 bash "$P" --lint "$W/whysecond.txt"; has 'Why: bullet must be the first bullet'; ok
t "an authorship trailer fails" 1 bash "$P" --lint "$W/trailer.txt"; has 'authorship trailer'; ok
t "seven bullets fail" 1 bash "$P" --lint "$W/seven.txt"; has 'hard cap 6'; ok
t "an -ing bullet warns and still passes" 0 bash "$P" --lint "$W/ing.txt"; has '^LINT WARN: bullet opens with an -ing word'; ok
t "a body with no blank line 2 fails" 1 bash "$P" --lint "$W/noblank.txt"; has 'line 2 must be blank'; ok
t "bullets with the code as subject pass, edits with no new behavior too" 0 bash "$P" --lint "$W/subject.txt"; has '^lint: message OK'; lacks 'LINT WARN'; ok
t "a bullet that opens with a command verb warns, naming its line" 0 bash "$P" --lint "$W/command.txt"; has '^LINT WARN: bullet opens with a command verb.*: 4:- Add `test_double_space`'; ok
t "each passive bullet warns" 0 bash "$P" --lint "$W/passive.txt"
has '^LINT WARN: passive verb.*: 3:- `isRecording` is set by `Session`'; has '^LINT WARN: passive verb.*: 4:- `refreshAll` is no longer called'; ok
t "a passive Why:, wrapped or not, does not warn" 0 bash "$P" --lint "$W/whypassive.txt"; lacks 'LINT WARN'; ok
t "a participle that names a state does not warn" 0 bash "$P" --lint "$W/state.txt"; lacks 'LINT WARN'; ok

echo
echo "== lint: a repo that enforces its own format, and the repo's history deciding ASCII"
repo enforced; commitlint
t "under commitlint, a subject the skill's format rejects passes" 0 bash "$P" --lint "$W/plain.txt"; has 'repo enforces its own subject format \(commitlint.config.js\)'; ok
t "under commitlint, brackets pass" 0 bash "$P" --lint "$W/ticket.txt"; ok
t "under commitlint, an emoji fails while the repo's subjects are ASCII" 1 bash "$P" --lint "$W/gitmoji.txt"; has 'non-ASCII characters'; ok
repo gitmoji '✨ add search' '🐛 fix crash on launch'; commitlint
t "where the repo's own subjects use emoji, an emoji subject passes" 0 bash "$P" --lint "$W/gitmoji.txt"; has '2 of the repo.s last 20 subjects use non-ASCII'; ok
repo emoji-history 'feat(app): start' 'fix(app): stop the crash 🐛'
t "the history decides without an enforcer too" 0 bash "$P" --lint "$W/emoji.txt"; has 'the ASCII check is skipped'; ok

echo
echo "== lint: the branch's ticket key"
repo ticket; git switch -q -c feature/WID-12-login
t "a subject without the branch's ticket key warns" 0 bash "$P" --lint "$W/keyless.txt"; has '^LINT WARN: subject lacks the ticket key WID-12'; ok
t "a subject with the key passes" 0 bash "$P" --lint "$W/keyed.txt"; lacks 'LINT WARN'; ok
git switch -q -c fix/UTF-8-decoding
t "an encoding name in the branch is no ticket key" 0 bash "$P" --lint "$W/keyless.txt"; lacks 'ticket key'; ok

echo
echo "== the --commit gate: what lands, and each stop's exit and label"
repo gate
echo a2 > a.txt; echo b2 > b.txt
t "a clean message commits exactly the named path" 0 bash "$P" --commit "$W/ok.txt" -- a.txt
head_is 'feat(ui): add dark mode toggle'; in_head a.txt; not_in_head b.txt; index_clean; ok
echo a3 > a.txt
t "a failing message stops with exit 1 and names the cause" 1 bash "$P" --commit "$W/fmt.txt" -- a.txt
has '^LINT FAIL'; has '^NOT COMMITTED: lint failed'; head_is 'feat(ui): add dark mode toggle'; index_clean; ok
t "a warned message stops with exit 2" 2 bash "$P" --commit "$W/ing.txt" -- a.txt
has '^NOT COMMITTED: lint warned'; head_is 'feat(ui): add dark mode toggle'; ok
t "--accept-warnings commits a warned message" 0 bash "$P" --commit "$W/ing.txt" --accept-warnings -- a.txt
head_is 'fix(api): retry the upload'; ok
echo a4 > a.txt; git add b.txt
t "paths named while changes are staged stop with exit 1" 1 bash "$P" --commit "$W/ok2.txt" -- a.txt
has '^NOT COMMITTED: changes are staged'; head_is 'fix(api): retry the upload'; staged b.txt; ok
git reset -q
t "no paths and nothing staged stop with exit 1" 1 bash "$P" --commit "$W/ok2.txt"; has '^NOT COMMITTED: nothing staged'; ok
t "--amend with paths stops with exit 1" 1 bash "$P" --commit "$W/amend.txt" --amend -- a.txt; has '^NOT COMMITTED: --amend takes the index'; ok
git add a.txt
t "single mode commits the index and leaves unstaged changes" 0 bash "$P" --commit "$W/ok2.txt"
head_is 'fix(ui): keep the toggle state'; in_head a.txt; not_in_head b.txt
git diff --name-only | grep -qx b.txt || why "b.txt is no longer modified in the tree"; ok
git add b.txt
t "a message-only amend rewords and leaves the index alone" 0 bash "$P" --commit "$W/amend.txt" --amend --message-only
head_is 'fix(ui): keep the toggle state on reload'; not_in_head b.txt; staged b.txt; ok
git reset -q
printf '#!/bin/sh\necho "commit-msg: subject rejected by the team rule" >&2\nexit 1\n' > .git/hooks/commit-msg; chmod +x .git/hooks/commit-msg
echo a5 > a.txt
t "a commit-msg hook rejection exits 4, named as that hook" 4 bash "$P" --commit "$W/hook.txt" -- a.txt
has 'subject rejected by the team rule'; has '^NOT COMMITTED: the commit-msg hook rejected the message.* — rewrite the subject'; head_is 'fix(ui): keep the toggle state on reload'; ok
t "the same rejection again on the same message hands back to the user" 4 bash "$P" --commit "$W/hook.txt" -- a.txt
has '^NOT COMMITTED: the commit-msg hook rejected the message.* — the same stop as the last run on this message: hand back'; ok
rm .git/hooks/commit-msg
printf '#!/bin/sh\ngit status --short >/dev/null\necho "pre-commit: format check failed" >&2\nexit 1\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
t "a pre-commit hook failure exits 3, even when the hook runs git itself" 3 bash "$P" --commit "$W/ok.txt" -- a.txt
has 'format check failed'; has '^NOT COMMITTED: the pre-commit hook failed.* — fix what it flags'; head_is 'fix(ui): keep the toggle state on reload'; ok
rm .git/hooks/pre-commit
git config commit.gpgsign true; git config gpg.program false
t "git refusing on its own, here a failed signature, exits 5 and goes to the user" 5 bash "$P" --commit "$W/ok.txt" -- a.txt
has '^NOT COMMITTED: git refused the commit \(exit 128\).* — nothing in the message or the files fixes this'; ok
printf '#!/bin/sh\ngit -c alias.boom="!false" boom\nexit 0\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
t "a failing git command inside a passing hook is not that hook failing" 5 bash "$P" --commit "$W/ok.txt" -- a.txt
has '^NOT COMMITTED: git refused the commit \(exit 128\)'; ok
rm .git/hooks/pre-commit
git config --unset commit.gpgsign; git config --unset gpg.program
t "a lint stop on a message is a fix the first time" 2 bash "$P" --commit "$W/warn2.txt" -- a.txt; lacks 'hand back'; ok
t "the identical lint stop on the same message hands back" 2 bash "$P" --commit "$W/warn2.txt" -- a.txt; has '— the same stop as the last run on this message: hand back'; ok
t "a commit that lands clears the message's stop record" 0 bash "$P" --commit "$W/warn2.txt" --accept-warnings -- a.txt
[ -e "$W/warn2.txt.stop" ] && why "warn2.txt.stop is still there"; ok

echo
echo "== the preflight report"
repo report
t "a clean tree stops the run" 0 bash "$P"; has '^NOTHING TO COMMIT'; ok
echo a2 > a.txt
t "unstaged changes alone mean grouped mode" 0 bash "$P"; has '^mode: GROUPED'; has '^subject format: type\(scope\)'; has '^subject characters: ASCII only'; ok
git add a.txt
t "staged changes mean single mode" 0 bash "$P"; has '^mode: SINGLE'; ok
git reset -q; commitlint
t "a commitlint config is reported as the repo's format" 0 bash "$P"; has '^subject format: REPO-ENFORCED \(commitlint.config.js\)'; ok
cd "$W/gitmoji" || exit 1; echo a2 > a.txt
t "emoji in the repo's subjects are reported" 0 bash "$P"; has '^subject characters: 2 of the last 20 subjects use non-ASCII'; ok
cd "$W/ticket" || exit 1; git switch -q feature/WID-12-login; echo a2 > a.txt
t "the branch's ticket key is reported" 0 bash "$P"; has '^ticket key: WID-12, from the branch name'; ok

echo
echo "== the amend report"
repo amend 'chore: start' 'fix(ui): keep the toggle state'
t "a clean tree does not stop it, and it shows the last commit and the subject facts" 0 bash "$P" --amend
lacks 'NOTHING TO COMMIT'; has '^subject format: type\(scope\)'; has '^ +[0-9a-f]+ fix\(ui\): keep the toggle state'; has '^remote: no upstream'; ok
echo a2 > a.txt; echo b2 > b.txt; git add b.txt
t "it separates what an amend folds in from what stays out" 0 bash "$P" --amend
printf '%s\n' "$OUT" | sed -n '/^-- staged/,/^-- unstaged/p' | grep -q 'b.txt' || why "b.txt is not under staged"
printf '%s\n' "$OUT" | sed -n '/^-- unstaged/,/^-- recent/p' | grep -q 'a.txt' || why "a.txt is not under unstaged"; ok
git reset -q; git init -q --bare "$W/amend-remote.git"; git remote add origin "$W/amend-remote.git"; git push -q -u origin main 2>/dev/null
t "a commit already pushed is reported as needing a force-push" 0 bash "$P" --amend; has '^remote: the last commit is already on origin/main — updating it after the amend takes a force-push'; ok

echo
echo "== --size"
repo size
echo '{}' > package-lock.json; git add package-lock.json; git commit -qm "chore: add lockfile"
printf 'x\ny\n' >> a.txt; printf '{"a":1}\n' > package-lock.json
t "lockfiles are left out of the review size" 0 bash "$P" --size a.txt package-lock.json
has 'review size: 2 changed lines in 1 files \(1 lockfile or binary files left out\)'; ok

echo
echo "$PASS passed, $FAILS failed"
[ "$FAILS" = 0 ]
