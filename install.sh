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

# Fallback colors (colors.sh not available yet)
_is_tty() { [ -t 1 ]; }
c() {
  _is_tty || return 0
  case "$1" in
    green)       printf '\033[0;32m' ;;
    bold_yellow) printf '\033[1;33m' ;;
    red)         printf '\033[0;31m' ;;
    bold_red)    printf '\033[1;31m' ;;
    bold_cyan)   printf '\033[1;36m' ;;
    cyan)        printf '\033[0;36m' ;;
    off)         printf '\033[0m' ;;
    *) return 0 ;;
  esac
}

# ── Check requirements ────────────────────────────────────────

echo ""
printf '%sChecking requirements ...%s\n' "$(c bold_cyan)" "$(c off)"
echo ""

_missing=false

check_cmd() {
  if command -v "$1" &>/dev/null; then
    local _ver
    _ver=$("$1" --version 2>/dev/null | head -1 || echo "ok")
    printf '  %s[+]%s %-12s %s\n' "$(c green)" "$(c off)" "$1" "$_ver"
  else
    printf '  %s[x]%s %-12s %s%s%s\n' "$(c red)" "$(c off)" "$1" "(" "$(c red)" "not found$(c off))"
    _missing=true
  fi
}

check_cmd git
check_cmd node
check_cmd npm
check_cmd gpg

echo ""

if $_missing; then
  printf '%s[x]%s Missing required tools. Please install them before continuing.\n' "$(c red)" "$(c off)"
  echo ""
  echo "  Install instructions:"
  echo ""
  echo "    git:   https://git-scm.com/downloads"
  echo "    node:  https://nodejs.org (includes npm)"
  echo "    gpg:   https://gnupg.org/download"
  echo ""
  echo "  Or on Debian/Ubuntu:"
  echo "    sudo apt install git nodejs npm gnupg"
  echo ""
  echo "  Or on Arch:"
  echo "    sudo pacman -S git nodejs npm gnupg"
  echo ""
  echo "  Or on macOS:"
  echo "    brew install git node npm gnupg"
  echo ""
  exit 1
fi

# ── Clone and install ─────────────────────────────────────────

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
