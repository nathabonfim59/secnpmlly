#!/usr/bin/env bash
# bump.sh - Bump secnpmlly version, commit, and prepare for tagging.
#
# Usage:
#   bash scripts/bump.sh patch     0.4.0 -> 0.4.1
#   bash scripts/bump.sh minor     0.4.0 -> 0.5.0
#   bash scripts/bump.sh major     0.4.0 -> 1.0.0
#   bash scripts/bump.sh 2.0.0     explicit version
#
set -euo pipefail

VERSION_FILE="secnpmlly/version"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_DIR"

source "$REPO_DIR/secnpmlly/colors.sh"

CURRENT=$(cat "$VERSION_FILE" | tr -d '[:space:]')

bump_version() {
  local current="$1"
  local part="$2"

  IFS='.' read -r major minor patch <<< "$current"

  case "$part" in
    patch) echo "$major.$minor.$((patch + 1))" ;;
    minor) echo "$major.$((minor + 1)).0" ;;
    major) echo "$((major + 1)).0.0" ;;
    *)     echo "$part" ;;
  esac
}

if [ $# -lt 1 ]; then
  printf '%s[x]%s Usage: bash scripts/bump.sh <patch|minor|major|version>\n' "$(c red)" "$(c off)"
  exit 1
fi

NEW=$(bump_version "$CURRENT" "$1")

printf '%s[i]%s Bumping version: %s -> %s\n' "$(c cyan)" "$(c off)" "$CURRENT" "$NEW"

# Update version file
printf '%s\n' "$NEW" > "$VERSION_FILE"

# Commit
git add "$VERSION_FILE"
git commit -m "chore: bump version to $NEW"

printf '%s[+]%s Version bumped to %s\n' "$(c green)" "$(c off)" "$NEW"
echo ""
echo "Next steps:"
echo "  make tag      # create signed tag"
echo "  make push     # push commit + tag to origin"
echo ""
