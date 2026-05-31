#!/usr/bin/env bash
#
# One-liner install for secnpmlly
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/nathabonfim59/secnpmlly/main/install.sh | bash
#
set -euo pipefail

REPO_URL="https://github.com/nathabonfim59/secnpmlly.git"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/secnpmlly"
CLONE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/secnpmlly-install-XXXXXX")

cleanup() {
  rm -rf "$CLONE_DIR"
}
trap cleanup EXIT

source "$INSTALL_DIR/colors.sh" 2>/dev/null || true

# Fallback colors if not installed yet
if ! type c &>/dev/null; then
  _is_tty() { [ -t 1 ]; }
  c() {
    _is_tty || return 0
    case "$1" in
      green)       printf '\033[0;32m' ;;
      bold_yellow) printf '\033[1;33m' ;;
      red)         printf '\033[0;31m' ;;
      bold_cyan)   printf '\033[1;36m' ;;
      cyan)        printf '\033[0;36m' ;;
      off)         printf '\033[0m' ;;
      *) return 0 ;;
    esac
  }
fi

printf '%s[i]%s Cloning secnpmlly ...\n' "$(c cyan)" "$(c off)"
if ! git clone --depth 1 "$REPO_URL" "$CLONE_DIR/repo" 2>&1; then
  printf '%s[x]%s Failed to clone repository.\n' "$(c red)" "$(c off)"
  exit 1
fi

printf '%s[i]%s Running installer ...\n' "$(c cyan)" "$(c off)"
cd "$CLONE_DIR/repo"
bash apply-protections.sh

printf '%s[i]%s Cleaning up ...\n' "$(c cyan)" "$(c off)"

echo ""
printf '%sDone!%s Reload your shell:\n' "$(c green)" "$(c off)"
echo "  source ~/.bashrc   # or ~/.zshrc"
echo ""
