#!/usr/bin/env bash
# fixtures.sh — builds the fixture repos the brief evidence cases ran in.
# Not part of the skill's run; the evidence README's method calls it.
#
# Usage: bash fixtures.sh <case> <dir>     case: 0001 | 0002
set -u
CASE="${1:?case}"; DIR="${2:?dir}"
mkdir -p "$DIR" && cd "$DIR" || exit 1
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
git init -q -b main

app() {
  mkdir -p src/routes
  cat > package.json <<'EOF'
{ "name": "shelf", "private": true, "type": "module", "scripts": { "test": "node --test" } }
EOF
  cat > src/routes/lists.js <<'EOF'
import { db } from "../db.js";

// GET /lists: the caller's reading lists, newest first.
export async function getLists(req, res) {
  const rows = await db.query(
    "select l.*, count(b.id) as books from lists l left join books b on b.list_id = l.id " +
    "where l.user_id = $1 group by l.id order by l.created_at desc",
    [req.user.id],
  );
  res.json(rows);
}
EOF
  cat > src/db.js <<'EOF'
export const db = { query: async () => [] };
EOF
}

case "$CASE" in
0001)
  # A large corpus: four real docs among 600 reference entries, so the old
  # scout's report ran past 40 KB. The caching rule and the deletion rule
  # conflict: a 10-minute per-user cache cannot meet a 5-minute deletion SLA.
  app
  cat > CLAUDE.md <<'EOF'
# shelf

A reading-list API. Node 22, plain ES modules, no framework.

## Workflow
Before any non-trivial code task, run /brief; after it, run /debrief.

## Commands
- `npm test` runs the suite.
EOF
  mkdir -p docs/conventions docs/architecture docs/requirements docs/planning
  cat > docs/_index.md <<'EOF'
# shelf docs

- [conventions/](conventions/_index.md): how code is written here
- [architecture/](architecture/_index.md): how the system fits together and why
- [requirements/](requirements/_index.md): what the product must do
- [planning/](planning/_index.md): active and future work
- [reference/](reference/_index.md): generated endpoint and table reference

## Cross-cutting axes
- data lifecycle: how long user data and its copies live · last audited: never
- caching: what is cached, for how long, and how it is purged · last audited: never
EOF
  cat > docs/conventions/_index.md <<'EOF'
# Conventions

- [caching.md](caching.md): what may be cached, keys, and lifetimes
- [api-endpoints.md](api-endpoints.md): route layout, validation, and response shape
EOF
  cat > docs/conventions/caching.md <<'EOF'
# Caching

## Rules

- Cache list endpoints per user for 10 minutes, keyed by `user:<id>:<route>`.
  **Why:** the list query joins four tables and was 70% of p95 latency in March.
- Never cache a response that includes another user's data.
- Use the shared `cache` module in `src/cache.js`; do not add an in-process map.
  **Why:** the API runs as three instances, so a local map serves stale data after a write.

See [data lifecycle](../architecture/data-lifecycle.md) for how deletion reaches cached copies.
EOF
  cat > docs/conventions/api-endpoints.md <<'EOF'
# API endpoints

- One file per resource in `src/routes/`, exporting one handler per route.
- Responses are JSON arrays or objects; never wrap them in `{ data: ... }`.
  **Why:** the mobile client parses bare arrays, and a wrapper broke it once.
EOF
  cat > docs/architecture/_index.md <<'EOF'
# Architecture

- [data-lifecycle.md](data-lifecycle.md): how user data is stored, copied, and deleted
EOF
  cat > docs/architecture/data-lifecycle.md <<'EOF'
# Data lifecycle

- Account deletion removes every copy of a user's data within 5 minutes, caches included.
  **Why:** the privacy policy promises five minutes, and a regulator asked to see the proof.
- Copies of user data are listed in this doc; a new copy is added here before it ships.
EOF
  printf '# Requirements\n\n- [reading-lists.md](reading-lists.md): what a reading list holds and who can see it\n' > docs/requirements/_index.md
  printf '# Reading lists\n\n- A list belongs to one user and is visible only to that user.\n' > docs/requirements/reading-lists.md
  printf '# Planning\n\n- [roadmap.md](roadmap.md): the next two milestones\n' > docs/planning/_index.md
  printf '# Roadmap\n\n- Milestone 3: sharing lists with friends.\n' > docs/planning/roadmap.md
  mkdir -p docs/reference
  printf '# Reference\n\n' > docs/reference/_index.md
  for i in $(seq 1 30); do
    d="docs/reference/area-$i"; mkdir -p "$d"
    printf -- '- [area-%s](area-%s/_index.md): generated reference for area %s of the schema\n' "$i" "$i" "$i" >> docs/reference/_index.md
    printf '# Area %s\n\n' "$i" > "$d/_index.md"
    for j in $(seq 1 20); do
      # The first table of half the areas carries the columns a real schema has, so the
      # noise uses the task's common words (user, lists, cache) as generated docs do.
      if [ "$j" = 1 ] && [ "$i" -le 15 ]; then
        printf '# Table t%s_%s\n\nColumns: id, user_id, list_id, cache_version, created_at.\nLists rows a user owns; repeat loads read the cache table.\n' "$i" "$j" > "$d/table-$j.md"
      else
        printf '# Table t%s_%s\n\nColumns: id, created_at, owner, status.\n' "$i" "$j" > "$d/table-$j.md"
      fi
      printf -- '- [table-%s.md](table-%s.md): columns and indexes of table t%s_%s, generated from the schema\n' "$j" "$j" "$i" "$j" >> "$d/_index.md"
    done
  done
  ;;
0002)
  # No docs/ at all; the conventions live in CLAUDE.md.
  app
  cat > CLAUDE.md <<'EOF'
# shelf

A reading-list API. Node 22, plain ES modules, no framework.

## Conventions
- Routes live in `src/routes/`, one file per resource, one exported handler per route.
- Validate every request body and param with `zod` before touching the database.
- A handler that changes data returns 204 with no body.

## Commands
- `npm test` runs the suite.
EOF
  ;;
*) echo "unknown case $CASE"; exit 1 ;;
esac
git add -A && git commit -qm "the state the case starts from"
