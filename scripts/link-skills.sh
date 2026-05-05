#!/usr/bin/env bash
# Links skills to ~/.claude/skills/ for global availability.
# Supports per-group linking or linking all groups at once.
#
# Usage:
#   ./scripts/link-skills.sh              # link all groups
#   ./scripts/link-skills.sh doc-driven-dev  # link one group

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$HOME/.claude/skills"

mkdir -p "$DEST"

COLLISIONS=0

link_group() {
  local group_dir="$1"
  local skills_dir="$group_dir/skills"

  if [[ ! -d "$skills_dir" ]]; then
    return
  fi

  while IFS= read -r -d '' skill_md; do
    src="$(dirname "$skill_md")"
    name="$(basename "$src")"

    # Check for collision with an existing symlink from a different group
    if [[ -L "$DEST/$name" ]]; then
      existing="$(readlink "$DEST/$name")"
      if [[ "$existing" != "$src" ]]; then
        echo "WARNING: '$name' already linked to $existing — overwriting with $src" >&2
        COLLISIONS=1
      fi
    fi

    ln -sfn "$src" "$DEST/$name"
    echo "Linked: $name -> $src"
  done < <(find "$skills_dir" -name SKILL.md -not -path '*/node_modules/*' -print0)
}

if [[ $# -gt 0 ]]; then
  # Link specific group(s)
  for group in "$@"; do
    group_dir="$REPO/$group"
    if [[ ! -d "$group_dir" ]]; then
      echo "Error: group '$group' not found at $group_dir" >&2
      exit 1
    fi
    echo "Linking group: $group"
    link_group "$group_dir"
  done
else
  # Link all groups (directories containing a skills/ subdirectory)
  for group_dir in "$REPO"/*/; do
    [[ -d "$group_dir/skills" ]] || continue
    echo "Linking group: $(basename "$group_dir")"
    link_group "$group_dir"
  done
fi

if [[ "$COLLISIONS" -eq 1 ]]; then
  echo ""
  echo "WARNING: Naming collisions detected. Skill names must be unique across groups."
  echo "Consider renaming conflicting skills or using only one of the colliding groups."
fi

echo "Done. Skills available globally via /skill-name."
