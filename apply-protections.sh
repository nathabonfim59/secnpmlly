#!/usr/bin/env bash
#
# apply-protections.sh - Install secnpmlly: supply-chain protection for npm/pnpm/Yarn/bun
#
# Run:  bash apply-protections.sh
#
# Can be run from:
#   - A git clone (SOURCE_DIR = <script_dir>/secnpmlly)
#   - The managed repo at $INSTALL_DIR/repo (installed via curl)
#

set -euo pipefail

# ---------- Config ----------

INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/secnpmlly"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Resolve SOURCE_DIR: either next to this script, or from the managed repo
if [[ -d "$SCRIPT_DIR/secnpmlly" ]]; then
  SOURCE_DIR="$SCRIPT_DIR/secnpmlly"
elif [[ -d "$INSTALL_DIR/repo/secnpmlly" ]]; then
  SOURCE_DIR="$INSTALL_DIR/repo/secnpmlly"
else
  echo "Error: Cannot find secnpmlly/ directory."
  exit 1
fi

# ---------- Colors (shared with runtime) ----------

source "$SOURCE_DIR/colors.sh"

# Convenience wrappers using c()
info()  { printf '%s[+]%s %s\n' "$(c green)" "$(c off)" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$(c bold_yellow)" "$(c off)" "$*"; }
die()   { printf '%s[x]%s %s\n' "$(c red)" "$(c off)" "$*"; exit 1; }

# ---------- Helpers ----------

ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
  fi
}

# ---------- 0. Requirements ----------

check_requirements() {
  local _missing=false
  local _cmd

  for _cmd in git node npm gpg; do
    if ! command -v "$_cmd" &>/dev/null; then
      if ! $_missing; then
        echo ""
        warn "Missing required tools:"
      fi
      printf '    %s[x]%s %s\n' "$(c red)" "$(c off)" "$_cmd"
      _missing=true
    fi
  done

  if $_missing; then
    echo ""
    die "Install the missing tools and re-run this script."
  fi
}

# ---------- 1. Config files ----------

# 1a. npm (~/.npmrc)
apply_npmrc() {
  local npmrc="$HOME/.npmrc"

  declare -A wants=(
    [min-release-age]="7"
    [ignore-scripts]="true"
    [allow-git]="none"
  )

  declare -A current
  if [[ -f "$npmrc" ]]; then
    while IFS='=' read -r key val; do
      [[ "$key" =~ ^[[:space:]]*$ ]] && continue
      key=$(echo "$key" | xargs)
      val=$(echo "$val" | xargs)
      current["$key"]="$val"
    done < "$npmrc"
  fi

  local changed=false
  for key in min-release-age ignore-scripts allow-git; do
    want="${wants[$key]}"
    if [[ "${current[$key]:-}" != "$want" ]]; then
      if [[ -f "$npmrc" ]]; then
        sed -i "/^${key}=/d" "$npmrc" 2>/dev/null || true
      fi
      echo "${key}=${want}" >> "$npmrc"
      changed=true
    fi
  done

  if $changed || [[ ! -f "$npmrc" ]]; then
    info "npmrc     -> ${npmrc} updated"
  else
    info "npmrc     -> ${npmrc} already correct"
  fi
}

# 1b. bun (~/.bunconfig.toml)
apply_bunconf() {
  local bunconf="$HOME/.bunconfig.toml"

  local desired
  desired=$(printf '%s\n' '[install]' 'minimumReleaseAge = 604800' 'ignore-scripts = true')

  local write=true
  if [[ -f "$bunconf" ]]; then
    local existing
    existing=$(tr -d '\r' < "$bunconf" | sed '/^$/d')
    if [[ "$existing" == "${desired}" ]]; then
      write=false
    fi
  fi

  if $write; then
    printf '%s' "$desired" > "$bunconf"
    info "bunconf   -> ${bunconf} written"
  else
    info "bunconf   -> ${bunconf} already correct"
  fi
}

# 1c. pnpm (~/.config/pnpm/config.yaml)
apply_pnpmconf() {
  local confdir="$HOME/.config/pnpm"
  local conf="$confdir/config.yaml"

  ensure_dir "$confdir"

  local desired
  desired=$(printf '%s\n' 'minimumReleaseAge: 10080' 'blockExoticSubdeps: true' 'trustPolicy: no-downgrade')

  local write=true
  if [[ -f "$conf" ]]; then
    local existing
    existing=$(tr -d '\r' < "$conf" | sed '/^$/d')
    if [[ "$existing" == "${desired}" ]]; then
      write=false
    fi
  fi

  if $write; then
    printf '%s' "$desired" > "$conf"
    info "pnpmconf  -> ${conf} written"
  else
    info "pnpmconf  -> ${conf} already correct"
  fi
}

# ---------- 2. Install secnpmlly files ----------

install_secnpmlly() {
  if [[ ! -d "$SOURCE_DIR" ]]; then
    die "Cannot find secnpmlly/ directory"
  fi

  ensure_dir "$INSTALL_DIR/wrappers"
  ensure_dir "$INSTALL_DIR/keys"
  ensure_dir "$INSTALL_DIR/validators"

  # Copy runtime files (sourced by shell rc)
  cp "$SOURCE_DIR/version"      "$INSTALL_DIR/version"
  cp "$SOURCE_DIR/secnpmlly.sh" "$INSTALL_DIR/secnpmlly.sh"
  cp "$SOURCE_DIR/colors.sh"    "$INSTALL_DIR/colors.sh"
  cp "$SOURCE_DIR/helpers.sh"   "$INSTALL_DIR/helpers.sh"
  cp "$SOURCE_DIR/wrappers/"*.sh "$INSTALL_DIR/wrappers/"
  cp "$SOURCE_DIR/validators/"*.js "$INSTALL_DIR/validators/"

  # Install trusted public key (if present)
  if [[ -f "$SOURCE_DIR/keys/trusted.asc" ]]; then
    cp "$SOURCE_DIR/keys/trusted.asc" "$INSTALL_DIR/keys/trusted.asc"

    # Check if already imported
    local _fp
    _fp=$(gpg --with-fingerprint --with-colons "$INSTALL_DIR/keys/trusted.asc" 2>/dev/null \
      | grep '^fpr:' | head -1 | cut -d: -f10)
    local _already=false
    if [[ -n "$_fp" ]]; then
      gpg --list-keys --with-colons "$_fp" &>/dev/null && _already=true
    fi

    if ! $_already; then
      echo ""
      printf '%s--------------------------------------------------------------%s\n' "$(c bold_cyan)" "$(c off)"
      printf '%s  GPG Public Key Import%s\n' "$(c bold_cyan)" "$(c off)"
      printf '%s--------------------------------------------------------------%s\n' "$(c bold_cyan)" "$(c off)"
      echo ""
      echo "  secnpmlly verifies that every update is signed by the maintainer's"
      echo "  GPG key. This protects you from tampered releases."
      echo ""
      echo "  We need to import this public key into your GPG keyring so that"
      echo "  'secnpmlly update' can verify signatures."
      echo ""
      echo "  Key details:"
      gpg --with-fingerprint "$INSTALL_DIR/keys/trusted.asc" 2>/dev/null \
        | grep -E '(pub|uid|sub|Key fingerprint)' \
        | sed 's/^/    /'
      echo ""
      printf '  %sImport this key into your GPG keyring? [Y/n]%s ' "$(c bold_yellow)" "$(c off)"
      read -r _answer </dev/tty
      case "$_answer" in
        n|N|no|No|NO)
          warn "Key not imported. secnpmlly update will skip signature verification."
          warn "You can import it later: gpg --import $INSTALL_DIR/keys/trusted.asc"
          ;;
        *)
          gpg --import "$INSTALL_DIR/keys/trusted.asc" 2>/dev/null || true
          info "secnpmlly -> trusted GPG key imported"
          ;;
      esac
    else
      info "secnpmlly -> trusted GPG key already in keyring"
    fi
  fi

  # Install uninstall script
  local _uninstall_src
  _uninstall_src="$(dirname "$SOURCE_DIR")/uninstall.sh"
  if [[ -f "$_uninstall_src" ]]; then
    cp "$_uninstall_src" "$INSTALL_DIR/uninstall.sh"
    chmod +x "$INSTALL_DIR/uninstall.sh"
  fi

  # Install CLI binary into ~/.local/bin
  local bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
  ensure_dir "$bin_dir"
  [ -L "$bin_dir/secnpmlly" ] && rm -f "$bin_dir/secnpmlly"
  cp "$SOURCE_DIR/bin/secnpmlly" "$bin_dir/secnpmlly"
  chmod +x "$bin_dir/secnpmlly"

  info "secnpmlly -> installed to $INSTALL_DIR"
  info "secnpmlly -> CLI installed at $bin_dir/secnpmlly"
}

# ---------- 3. Global tools ----------

install_npq() {
  if command -v npq &>/dev/null; then
    info "npq       -> already installed ($(npq --version 2>/dev/null || echo 'unknown'))"
  else
    info "npq       -> installing globally ..."
    npm install -g npq
    info "npq       -> installed"
  fi
}

# ---------- 4. Shell rc hooks ----------

MARKER='# >>> secnpmlly >>>'
MARKER_END='# <<< secnpmlly <<<'

apply_rc_hooks() {
  local shell_name
  shell_name=$(basename "${SHELL:-/bin/bash}")

  for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
    local base
    base=$(basename "$rc")

    if [[ ! -f "$rc" ]]; then
      if [[ "$base" == ".${shell_name}rc" ]]; then
        touch "$rc"
        info "created $rc"
      else
        continue
      fi
    fi

    # Already patched? -> skip
    if grep -qF "$MARKER" "$rc" 2>/dev/null; then
      info "rc hook   -> ${rc} already patched"
      continue
    fi

    # Append new minimal hook
    printf '\n%s\nsource "%s/secnpmlly.sh"\n%s\n' "$MARKER" "$INSTALL_DIR" "$MARKER_END" >> "$rc"
    info "rc hook   -> ${rc} updated"
  done
}

# ---------- main ----------

VERSION=$(cat "$SOURCE_DIR/version" 2>/dev/null | tr -d '[:space:]' || echo "unknown")

echo ""
printf '%s========================================%s\n' "$(c bold_cyan)" "$(c off)"
printf '%s  secnpmlly %s%s\n' "$(c bold_cyan)" "$VERSION" "$(c off)"
printf '%s  Supply-chain protection setup%s\n' "$(c bold_cyan)" "$(c off)"
printf '%s========================================%s\n' "$(c bold_cyan)" "$(c off)"
echo ""

check_requirements

apply_npmrc
apply_bunconf
apply_pnpmconf

echo ""
install_secnpmlly
install_npq

echo ""
apply_rc_hooks

echo ""
printf '%sAll done.%s\n' "$(c green)" "$(c off)"
echo ""
printf '%sReload your shell (source ~/.bashrc or ~/.zshrc) to activate.%s\n' "$(c bold_yellow)" "$(c off)"
echo ""
echo "Then run: secnpmlly status"
echo ""
