#!/usr/bin/env bash
#
# uninstall.sh - Remove secnpmlly and all changes it made
#
# Run:  bash uninstall.sh
#

set -euo pipefail

INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/secnpmlly"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
MARKER='# >>> secnpmlly >>>'
MARKER_END='# <<< secnpmlly <<<'

# ---------- Colors (inline fallback; colors.sh may already be gone) ----------

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

info()  { printf '%s[-]%s %s\n' "$(c cyan)" "$(c off)" "$*"; }
ok()    { printf '%s[+]%s %s\n' "$(c green)" "$(c off)" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$(c bold_yellow)" "$(c off)" "$*"; }

# ---------- Collect trusted key fingerprint before removing files ----------

_trusted_fp=''
_keyfile="$INSTALL_DIR/keys/trusted.asc"
if [ -f "$_keyfile" ]; then
  _trusted_fp=$(gpg --with-fingerprint --with-colons "$_keyfile" 2>/dev/null \
    | grep '^fpr:' | head -1 | cut -d: -f10 || true)
fi

# ---------- Banner ----------

echo ""
printf '%s========================================%s\n' "$(c bold_cyan)" "$(c off)"
printf '%s  secnpmlly uninstall%s\n' "$(c bold_cyan)" "$(c off)"
printf '%s========================================%s\n' "$(c bold_cyan)" "$(c off)"
echo ""

# ---------- 1. Shell rc hooks ----------

for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] || continue
  if grep -qF "$MARKER" "$rc" 2>/dev/null; then
    sed -i "/^${MARKER}/,/^${MARKER_END}/d" "$rc"
    ok "rc hook   -> removed from $rc"
  else
    info "rc hook   -> not found in $rc, skipping"
  fi
done

# ---------- 2. CLI binary ----------

if [ -f "$BIN_DIR/secnpmlly" ]; then
  rm -f "$BIN_DIR/secnpmlly"
  ok "binary    -> removed $BIN_DIR/secnpmlly"
else
  info "binary    -> not found at $BIN_DIR/secnpmlly, skipping"
fi

# ---------- 3. GPG public key ----------

if [ -n "$_trusted_fp" ]; then
  if gpg --list-keys --with-colons "$_trusted_fp" &>/dev/null; then
    gpg --batch --yes --delete-key "$_trusted_fp" 2>/dev/null && \
      ok "gpg key   -> removed $_trusted_fp from keyring" || \
      warn "gpg key   -> could not remove $_trusted_fp (remove manually: gpg --delete-key $_trusted_fp)"
  else
    info "gpg key   -> not in keyring, skipping"
  fi
else
  info "gpg key   -> trusted.asc not found, skipping key removal"
fi

# ---------- 4. Install directory ----------

if [ -d "$INSTALL_DIR" ]; then
  rm -rf "$INSTALL_DIR"
  ok "files     -> removed $INSTALL_DIR"
else
  info "files     -> $INSTALL_DIR not found, skipping"
fi

# ---------- 5. ~/.npmrc entries ----------

_npmrc="$HOME/.npmrc"
if [ -f "$_npmrc" ]; then
  sed -i '/^min-release-age=/d' "$_npmrc"
  sed -i '/^ignore-scripts=/d' "$_npmrc"
  sed -i '/^allow-git=/d' "$_npmrc"
  ok "npmrc     -> removed secnpmlly entries from $_npmrc"
else
  info "npmrc     -> not found, skipping"
fi

# ---------- 6. ~/.bunconfig.toml ----------

_bunconf="$HOME/.bunconfig.toml"
_bun_expected=$(printf '%s\n' '[install]' 'minimumReleaseAge = 604800' 'ignore-scripts = true')
if [ -f "$_bunconf" ]; then
  _bun_existing=$(tr -d '\r' < "$_bunconf" | sed '/^$/d')
  if [ "$_bun_existing" = "$_bun_expected" ]; then
    rm -f "$_bunconf"
    ok "bunconf   -> removed $_bunconf"
  else
    warn "bunconf   -> $_bunconf has been modified; not removing (review manually)"
  fi
else
  info "bunconf   -> not found, skipping"
fi

# ---------- 7. ~/.config/pnpm/config.yaml ----------

_pnpmconf="$HOME/.config/pnpm/config.yaml"
_pnpm_expected=$(printf '%s\n' 'minimumReleaseAge: 10080' 'blockExoticSubdeps: true' 'trustPolicy: no-downgrade')
if [ -f "$_pnpmconf" ]; then
  _pnpm_existing=$(tr -d '\r' < "$_pnpmconf" | sed '/^$/d')
  if [ "$_pnpm_existing" = "$_pnpm_expected" ]; then
    rm -f "$_pnpmconf"
    ok "pnpmconf  -> removed $_pnpmconf"
  else
    warn "pnpmconf  -> $_pnpmconf has been modified; not removing (review manually)"
  fi
else
  info "pnpmconf  -> not found, skipping"
fi

# ---------- Done ----------

echo ""
printf '%sUninstall complete.%s\n' "$(c green)" "$(c off)"
echo ""
echo "Reload your shell to deactivate wrappers for this session:"
echo "  exec \$SHELL"
echo ""
