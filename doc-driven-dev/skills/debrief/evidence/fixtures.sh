#!/usr/bin/env bash
# fixtures.sh — builds the fixture repo the debrief evidence case ran in.
# Not part of the skill's run; the evidence README's method calls it.
#
# Usage: bash fixtures.sh <case> <dir>
#   0001: builds <dir>/shelf (main) and the worktree <dir>/shelf-tokens, where
#         the arm runs: a branch of eight commits whose last is the code change.
#   0002: builds <dir>/notes on main: an old debrief's mark, a v1.2 tag after
#         it, and three commits since the tag; the arm runs in <dir>/notes.
set -u
CASE="${1:?case}"; DIR="${2:?dir}"
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
c() { git add -A && git commit -qm "$1"; }

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
  exit 0
fi

[ "$CASE" = 0001 ] || { echo "unknown case $CASE"; exit 1; }
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
cat > docs/architecture/auth.md <<'EOF'
# Auth

`/login` issues a signed access token that expires after 15 minutes.
`src/auth.js` reads the access token from `Authorization: Bearer <token>` on every request.
EOF
c "feat(auth): replace session tokens with bearer access tokens"
