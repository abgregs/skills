#!/usr/bin/env bash
# fixtures.sh — builds the fixture repo the setup-docs evidence case ran in.
# Not part of the skill's run; the evidence README's method calls it.
#
# Usage: bash fixtures.sh 0001 <dir>
set -u
CASE="${1:?case}"; DIR="${2:?dir}"
[ "$CASE" = 0001 ] || { echo "unknown case $CASE"; exit 1; }
mkdir -p "$DIR" && cd "$DIR" || exit 1
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
git init -q -b main

# A small Python CLI whose docs grew without a structure: an oversized
# ARCHITECTURE.md at the root, a docs/ folder with no indexes, a file that is
# not kebab-case, a loose notes folder, and conventions living in CLAUDE.md.
mkdir -p ledger docs/notes tests
cat > pyproject.toml <<'EOF'
[project]
name = "ledger-cli"
version = "0.4.0"
dependencies = ["click>=8", "sqlite-utils>=3"]
EOF
printf 'import click\n\n@click.group()\ndef cli():\n    """Track shared expenses."""\n' > ledger/cli.py
printf 'def add(db, amount, who):\n    db["entries"].insert({"amount": amount, "who": who})\n' > ledger/store.py
printf 'def test_add():\n    assert True\n' > tests/test_store.py
printf '# ledger-cli\n\nTrack shared expenses from the terminal.\n' > README.md
cat > CLAUDE.md <<'EOF'
# ledger-cli

## Conventions
- Amounts are integers in cents, never floats.
- Every command lives in ledger/cli.py and calls into ledger/store.py; no SQL in cli.py.
- Tests use a temporary sqlite file, never the user's real database.

## Commands
- `pytest` runs the tests.
EOF
{ echo "# Architecture"; echo; echo "## Storage"; for i in $(seq 1 60); do echo "Storage note $i: entries table, indexes, and migration $i."; done
  echo; echo "## Commands"; for i in $(seq 1 60); do echo "Command note $i: how command $i parses its options."; done
  echo; echo "## Release"; for i in $(seq 1 55); do echo "Release note $i: tagging and publishing step $i."; done; } > ARCHITECTURE.md
cat > docs/SetupGuide.md <<'EOF'
# Setup guide

1. Install with `pipx install ledger-cli`.
2. Run `ledger init` to create the database in ~/.ledger.
EOF
printf '# Splitting rules\n\nAn expense split unevenly records each share in cents.\n' > docs/splitting.md
printf '# TODO\n\n- Export to CSV.\n- Currency support.\n' > docs/notes/todo.md
git add -A && git commit -qm "the state the case starts from"
