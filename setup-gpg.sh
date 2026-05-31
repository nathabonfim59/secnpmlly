#!/usr/bin/env bash
#
# Setup GPG signing for the secnpmlly repo.
# Run this once on your machine. The private key NEVER leaves this machine.
#
# Usage:  bash setup-gpg.sh
#

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$REPO_DIR/secnpmlly/colors.sh"

echo ""
echo "This script will:"
echo "  1. Generate a GPG key"
echo "  2. Export the public key to secnpmlly/keys/trusted.asc"
echo "  3. Configure git signing (repo-local only)"
echo ""

# ── Step 1: Collect info ──────────────────────────────────────

echo -n "Enter your name for the GPG key (e.g. Nathanael Bonfim): "
read -r GPG_NAME
[ -z "$GPG_NAME" ] && { printf '%s[x]%s Name cannot be empty.\n' "$(c red)" "$(c off)"; exit 1; }

echo -n "Enter your email for the GPG key: "
read -r GPG_EMAIL
[ -z "$GPG_EMAIL" ] && { printf '%s[x]%s Email cannot be empty.\n' "$(c red)" "$(c off)"; exit 1; }

echo ""
printf '%s[i]%s Generating GPG key for %s <%s> ...\n' "$(c cyan)" "$(c off)" "$GPG_NAME" "$GPG_EMAIL"
echo "  (this may take a moment - gathering entropy)"
echo ""

# ── Step 2: Generate key ──────────────────────────────────────

BATCH_FILE=$(mktemp)
cat > "$BATCH_FILE" << EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: ${GPG_NAME}
Name-Email: ${GPG_EMAIL}
Expire-Date: 0
%commit
EOF

GPG_OUTPUT=$(gpg --batch --gen-key "$BATCH_FILE" 2>&1) || {
  rm -f "$BATCH_FILE"
  printf '%s[x]%s Failed to generate GPG key:\n' "$(c red)" "$(c off)"
  echo "$GPG_OUTPUT"
  exit 1
}
rm -f "$BATCH_FILE"

# Extract fingerprint by looking up the email we just generated
GPG_KEY_ID=$(gpg --list-keys --with-colons "${GPG_EMAIL}" 2>/dev/null \
  | grep '^fpr:' | head -1 | cut -d: -f10)

if [ -z "$GPG_KEY_ID" ]; then
  printf '%s[x]%s Key was generated but could not find fingerprint.\n' "$(c red)" "$(c off)"
  printf '%s[x]%s Check: gpg --list-keys "%s"\n' "$(c red)" "$(c off)" "$GPG_EMAIL"
  exit 1
fi

printf '%s[+]%s GPG key generated\n' "$(c green)" "$(c off)"
printf '    Fingerprint: %s\n' "$GPG_KEY_ID"
printf '    UID:          %s <%s>\n' "$GPG_NAME" "$GPG_EMAIL"

# ── Step 3: Export public key to repo ─────────────────────────

mkdir -p "$REPO_DIR/secnpmlly/keys"
gpg --armor --export "$GPG_KEY_ID" > "$REPO_DIR/secnpmlly/keys/trusted.asc"

if [ ! -s "$REPO_DIR/secnpmlly/keys/trusted.asc" ]; then
  printf '%s[x]%s Failed to export public key.\n' "$(c red)" "$(c off)"
  exit 1
fi

printf '%s[+]%s Public key exported to secnpmlly/keys/trusted.asc\n' "$(c green)" "$(c off)"

# ── Step 4: Configure git signing (repo-local only) ───────────

git -C "$REPO_DIR" config --local user.signingKey "$GPG_KEY_ID"
git -C "$REPO_DIR" config --local commit.gpgSign true
git -C "$REPO_DIR" config --local tag.gpgSign true

printf '%s[+]%s Git signing configured (repo-local only)\n' "$(c green)" "$(c off)"
echo ""
printf '%sDone!%s Here is what happened:\n' "$(c green)" "$(c off)"
echo ""
echo "  - Private key: stored ONLY in your local GPG keyring (~/.gnupg)"
echo "  - Public key:  secnpmlly/keys/trusted.asc (safe to commit and publish)"
echo "  - Git config:  repo-local only (not global)"
echo ""
echo "  Where things live:"
echo "    Private key  -> ~/.gnupg/                       (never leaves this machine)"
echo "    Public key   -> secnpmlly/keys/trusted.asc      (committed to the repo)"
echo "    Git signing  -> .git/config                      (repo-local, not global)"
echo ""
echo "To create a signed release tag:"
echo "  git tag -s v0.4.0 -m 'Release v0.4.0'"
echo "  git push origin v0.4.0"
echo ""
