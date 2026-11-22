#!/usr/bin/env bash
# fixtures.sh — builds the fixture repo the debrief evidence case ran in.
# Not part of the skill's run; the evidence README's method calls it.
#
# Usage: bash fixtures.sh <case> <dir>
#   0001: builds <dir>/shelf (main) and the worktree <dir>/shelf-tokens, where
#         the arm runs: a branch of eight commits whose last is the code change.
#   0002: builds <dir>/notes on main: an old debrief's mark, a v1.2 tag after
#         it, and three commits since the tag; the arm runs in <dir>/notes.
#   0003: builds <dir>/ledger on a branch with no commits of its own and the
#         change uncommitted: a staged code edit, an unstaged doc edit, and an
#         untracked file holding the new rule; the arm runs in <dir>/ledger.
#   0004: builds <dir>/ledger the same way, with a clean tree and no change.
#   0005: builds 0001's repo, but the branch changes code only: auth.md is
#         left as it was on main, so no doc line changes.
#   0006: builds <dir>/lists on a branch that adds a 10-minute per-user cache
#         and its convention, against a rule that deletion reaches caches
#         within 5 minutes; the arm runs in <dir>/lists and is answered.
#   0007: builds 0004's repo; the arm is answered with the range to review.
set -u
CASE="${1:?case}"; DIR="${2:?dir}"
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
c() { git add -A && git commit -qm "$1"; }

if [ "$CASE" = 0006 ]; then
  mkdir -p "$DIR/lists" && cd "$DIR/lists" || exit 1
  git init -q -b main
  mkdir -p src/routes docs/conventions docs/architecture
  printf '# lists\n\nA reading-list API. Node 22, plain ES modules.\n\n## Workflow\nAfter a code task, run /debrief.\n' > CLAUDE.md
  cat > docs/_index.md <<'EOF'
# lists docs

- [conventions/](conventions/_index.md): how code is written here
- [architecture/](architecture/_index.md): how the system fits together and why

## Cross-cutting axes
- data lifecycle: how user data is kept, copied, and deleted · last audited: never
EOF
  printf '# Conventions\n\n- [api-endpoints.md](api-endpoints.md): route layout and response shape\n' > docs/conventions/_index.md
  printf '# API endpoints\n\n- One file per resource in `src/routes/`.\n- Responses are bare JSON arrays or objects.\n' > docs/conventions/api-endpoints.md
  printf '# Architecture\n\n- [data-lifecycle.md](data-lifecycle.md): where user data lives and how it is deleted\n' > docs/architecture/_index.md
  cat > docs/architecture/data-lifecycle.md <<'EOF'
# Data lifecycle

- Account deletion removes every copy of a user's data within 5 minutes, caches included.
  **Why:** the privacy policy promises five minutes, and a regulator asked to see the proof.
- A new copy of user data is listed here before it ships.
EOF
  printf 'export const getLists = async (req, db) => db.query("select * from lists where user_id = ?", [req.user.id]);\n' > src/routes/lists.js
  printf 'export const deleteAccount = async (userId, db) => db.query("delete from users where id = ?", [userId]);\n' > src/accounts.js
  c "lists: routes and accounts"
  git checkout -q -b feat/list-cache
  cat > src/cache.js <<'EOF'
// Per-user cache for GET /lists: the list query was 70% of p95 latency.
const store = new Map();
export const TTL_MS = 10 * 60 * 1000;
export const cached = async (key, load) => {
  const hit = store.get(key);
  if (hit && Date.now() - hit.at < TTL_MS) return hit.value;
  const value = await load();
  store.set(key, { value, at: Date.now() });
  return value;
};
EOF
  printf 'import { cached } from "../cache.js";\nexport const getLists = async (req, db) => cached(`user:${req.user.id}:lists`, () => db.query("select * from lists where user_id = ?", [req.user.id]));\n' > src/routes/lists.js
  c "feat(lists): cache GET /lists per user"
  printf -- '- [caching.md](caching.md): what is cached, for how long, and under which key\n' >> docs/conventions/_index.md
  cat > docs/conventions/caching.md <<'EOF'
# Caching

- Cache `GET /lists` per user for 10 minutes, keyed `user:<id>:lists`.
  **Why:** the list query was 70% of p95 latency.
EOF
  c "docs(caching): document the list cache"
  exit 0
fi

if [ "$CASE" = 0003 ] || [ "$CASE" = 0004 ] || [ "$CASE" = 0007 ]; then
  mkdir -p "$DIR/ledger" && cd "$DIR/ledger" || exit 1
  git init -q -b main
  mkdir -p src docs/conventions docs/architecture
  printf '# ledger\n\nA household budgeting API. Node 22, plain ES modules.\n\n## Workflow\nAfter a code task, run /debrief.\n' > CLAUDE.md
  cat > docs/_index.md <<'EOF'
# ledger docs

- [conventions/](conventions/_index.md): how code is written here
- [architecture/](architecture/_index.md): how the system fits together and why

## Cross-cutting axes
- money: how amounts are stored, rounded, and shown · last audited: never
EOF
  printf '# Conventions\n\n- [money.md](money.md): how amounts are stored and rounded\n' > docs/conventions/_index.md
  cat > docs/conventions/money.md <<'EOF'
# Money

- Store every amount in `amount_dollars`, a float.
- Round to two places only when an amount is shown.
EOF
  printf '# Architecture\n\n- [entries.md](entries.md): the entries table and its columns\n' > docs/architecture/_index.md
  cat > docs/architecture/entries.md <<'EOF'
# Entries

Each entry row holds `id`, `account`, `posted_on`, and `amount_dollars`.
EOF
  printf 'export const entry = (account, amount_dollars) => ({ account, amount_dollars });\n' > src/ledger.js
  printf '# ledger\n' > README.md
  c "ledger: entries in dollars"
  # Unrelated work on main, which a HEAD~5 base would sweep in.
  for i in 1 2 3 4 5 6; do echo "- release note $i" >> README.md; c "chore: release note $i"; done
  git checkout -q -b feat/cents
  { [ "$CASE" = 0004 ] || [ "$CASE" = 0007 ]; } && exit 0
  # The change, none of it committed: the code edit staged, the doc edit
  # unstaged, and the new rule in a file not yet added.
  printf "import { toCents } from './currency.js';\nexport const entry = (account, dollars) => ({ account, amount_cents: toCents(dollars) });\n" > src/ledger.js
  git add src/ledger.js
  sed -i.bak 's/`amount_dollars`/`amount_cents`/' docs/architecture/entries.md && rm -f docs/architecture/entries.md.bak
  cat > src/currency.js <<'EOF'
// Every amount is an integer count of cents. Floats drifted: a month of
// 0.10 entries summed to 2.9999999999999996.
export const toCents = (dollars) => Math.round(dollars * 100);
EOF
  exit 0
fi

if [ "$CASE" = 0002 ]; then
  mkdir -p "$DIR/notes" && cd "$DIR/notes" || exit 1
  git init -q -b main
  mkdir -p src docs/conventions docs/requirements
  printf '# notes\n\nA note-taking web app.\n\n## Workflow\nAfter a code task, run /debrief.\n' > CLAUDE.md
  cat > docs/_index.md <<'EOF'
# notes docs

- [conventions/](conventions/_index.md): how code is written here
- [requirements/](requirements/_index.md): what the product must do

## Cross-cutting axes
- data lifecycle: how notes are kept, hidden, and deleted · last audited: never
EOF
  printf '# Conventions\n\n- [storage.md](storage.md): where notes and their states are stored\n' > docs/conventions/_index.md
  cat > docs/conventions/storage.md <<'EOF'
# Storage

- A note lives in the `notes` table; its folder is a `workspace` row.
- Archived notes keep their row with `archived_at` set.
EOF
  printf '# Requirements\n\n- [note-states.md](note-states.md): the states a note moves through\n' > docs/requirements/_index.md
  cat > docs/requirements/note-states.md <<'EOF'
# Note states

- A note in a workspace can be archived from its menu.
- Archived notes stay searchable.
EOF
  printf 'export const archive = (note) => ({ ...note, archived_at: Date.now() });\n' > src/notes.js
  printf 'export const search = (notes, q) => notes.filter((n) => n.body.includes(q));\n' > src/search.js
  c "notes: storage and states"
  # The debrief after that commit left its mark here.
  git rev-parse HEAD > .git/doc-sweep-mark
  # v1.2 renamed workspaces to folders; its own debrief kept "workspace" in
  # note-states.md on purpose, as the name users still see in the UI.
  sed -i.bak 's/its folder is a `workspace` row/its folder is a `folders` row/' docs/conventions/storage.md && rm -f docs/conventions/storage.md.bak
  c "feat(folders): rename the workspace table to folders"
  git tag v1.2
  # Since v1.2: archive becomes trash, and one doc still says archived.
  printf 'export const trash = (note) => ({ ...note, trashed_at: Date.now() });\n' > src/notes.js
  c "feat(notes): replace archive with trash"
  cat > docs/conventions/storage.md <<'EOF'
# Storage

- A note lives in the `notes` table; its folder is a `folders` row.
- Trashed notes keep their row with `trashed_at` set, and are purged after 30 days.
EOF
  c "docs(storage): trash replaces archive"
  printf '// trash purge runs nightly\n' >> src/notes.js
  c "feat(notes): purge trashed notes after 30 days"
  # Unrelated work in progress, which a doc commit must leave out: an unstaged
  # edit to a tracked file and a scratch file not yet added.
  printf '// WIP: match tags as well as the body\n' >> src/search.js
  printf '# scratch\n\n- try tag search with a prefix index\n' > scratch.md
  exit 0
fi

[ "$CASE" = 0001 ] || [ "$CASE" = 0005 ] || { echo "unknown case $CASE"; exit 1; }
mkdir -p "$DIR/shelf" && cd "$DIR/shelf" || exit 1
git init -q -b main

mkdir -p src docs/conventions docs/architecture docs/planning docs/reference
cat > CLAUDE.md <<'EOF'
# shelf

A reading-list API. Node 22, plain ES modules.

## Workflow
Before any non-trivial code task, run /brief; after it, run /debrief.
EOF
cat > src/auth.js <<'EOF'
// Reads the session token from the X-Session header and loads its user.
export function authenticate(req) {
  const token = req.headers["x-session"];
  return token ? lookupSession(token) : null;
}
function lookupSession(token) { return { id: token.slice(0, 8) }; }
EOF
cat > docs/_index.md <<'EOF'
# shelf docs

- [conventions/](conventions/_index.md): how code is written here
- [architecture/](architecture/_index.md): how the system fits together and why
- [reference/](reference/_index.md): generated schema reference

## Cross-cutting axes
- auth: how callers prove who they are, and how that proof ends · last audited: never
EOF
printf '# Conventions\n\n- [api-endpoints.md](api-endpoints.md): route layout, auth header, and response shape\n' > docs/conventions/_index.md
cat > docs/conventions/api-endpoints.md <<'EOF'
# API endpoints

- One file per resource in `src/routes/`.
- Every route but `/login` requires the session token in the `X-Session` header.
- Responses are bare JSON arrays or objects.
EOF
printf '# Architecture\n\n- [auth.md](auth.md): how a caller is authenticated\n' > docs/architecture/_index.md
cat > docs/architecture/auth.md <<'EOF'
# Auth

`/login` issues a session token, stored server-side for 30 days.
`src/auth.js` reads the session token from `X-Session` on every request.
EOF
# Standing faults the change does not touch: a planning folder with no
# index, and a reference doc over the 150-line limit.
printf '# Old notes\n\n- Try rate limits per user.\n' > docs/planning/old-notes.md
printf '# Reference\n\n- [schema.md](schema.md): every table and column, generated\n' > docs/reference/_index.md
{ echo "# Schema"; for i in $(seq 1 170); do echo "- t$i: id, created_at, owner"; done; } > docs/reference/schema.md
c "shelf: auth with session tokens"
git worktree add -q -b feat/access-tokens "$DIR/shelf-tokens"

cd "$DIR/shelf-tokens" || exit 1
for i in 1 2 3 4 5 6 7; do echo "// step $i of the token migration" >> src/auth.js; c "chore(auth): migration step $i"; done
cat > src/auth.js <<'EOF'
// Reads the bearer access token from the Authorization header and verifies it.
export function authenticate(req) {
  const header = req.headers["authorization"] ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  return token ? verifyAccessToken(token) : null;
}
function verifyAccessToken(token) { return { id: token.slice(0, 8) }; }
EOF
# 0005 stops short of the doc edit: the change is code only.
if [ "$CASE" = 0001 ]; then
  # The author records the replacement as the docs contract asks, naming the old header.
  cat > docs/architecture/auth.md <<'EOF'
# Auth

`/login` issues a signed access token that expires after 15 minutes.
`src/auth.js` reads the access token from `Authorization: Bearer <token>` on every request.
**Why:** replaces the 30-day server-side session token sent in `X-Session`: a leaked session token stayed valid for a month.
EOF
fi
c "feat(auth): replace session tokens with bearer access tokens"
