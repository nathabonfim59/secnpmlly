#!/usr/bin/env bash
#
# apply-protections.sh — Install secnpmlly: supply-chain protection for npm/pnpm/bun
#
# Run:  bash apply-protections.sh
#

set -euo pipefail

# ---------- Config ----------

INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/secnpmlly"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/secnpmlly"

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
    die "Cannot find secnpmlly/ directory next to this script"
  fi

  ensure_dir "$INSTALL_DIR/wrappers"
  ensure_dir "$INSTALL_DIR/keys"

  cp "$SOURCE_DIR/version"      "$INSTALL_DIR/version"
  cp "$SOURCE_DIR/secnpmlly.sh" "$INSTALL_DIR/secnpmlly.sh"
  cp "$SOURCE_DIR/colors.sh"    "$INSTALL_DIR/colors.sh"
  cp "$SOURCE_DIR/helpers.sh"   "$INSTALL_DIR/helpers.sh"
  cp "$SOURCE_DIR/wrappers/"*.sh "$INSTALL_DIR/wrappers/"

  # Install trusted public key (if present)
  if [[ -f "$SOURCE_DIR/keys/trusted.asc" ]]; then
    cp "$SOURCE_DIR/keys/trusted.asc" "$INSTALL_DIR/keys/trusted.asc"
    # Import into user's GPG keyring
    gpg --import "$INSTALL_DIR/keys/trusted.asc" 2>/dev/null || true
    info "secnpmlly -> trusted GPG key imported"
  fi

  # Store source repo path for secnpmlly update
  printf '%s' "$SCRIPT_DIR" > "$INSTALL_DIR/source"

  # Symlink CLI into ~/.local/bin
  local bin_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
  ensure_dir "$bin_dir"
  ln -sf "$SOURCE_DIR/bin/secnpmlly" "$bin_dir/secnpmlly"

  info "secnpmlly -> installed to $INSTALL_DIR"
  info "secnpmlly -> CLI linked at $bin_dir/secnpmlly"
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

install_lockfile_lint() {
  if command -v lockfile-lint &>/dev/null; then
    info "lockfile-lint -> already installed ($(lockfile-lint --version 2>/dev/null || echo 'unknown'))"
  else
    info "lockfile-lint -> installing globally ..."
    npm install -g lockfile-lint
    info "lockfile-lint -> installed"
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

apply_npmrc
apply_bunconf
apply_pnpmconf

echo ""
install_secnpmlly
install_npq
install_lockfile_lint

echo ""
apply_rc_hooks

echo ""
printf '%sAll done.%s\n' "$(c green)" "$(c off)"
echo ""
printf '%sReload your shell (source ~/.bashrc or ~/.zshrc) to activate.%s\n' "$(c bold_yellow)" "$(c off)"
echo ""
echo "Then run: secnpmlly status"
echo ""
