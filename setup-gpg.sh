#!/usr/bin/env bash
#
# Setup GPG signing for the secnpmlly repo.
# Run this once on your machine. The private key NEVER leaves this machine.
#
# Usage:  bash setup-gpg.sh
#

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "This script will:"
echo "  1. Generate a GPG key (if you don't have one)"
echo "  2. Export the public key to secnpmlly/keys/trusted.asc"
echo "  3. Configure git signing (repo-local only)"
echo ""

# ── Step 1: Check for existing key or generate ────────────────

echo -n "Enter your name for the GPG key (e.g. Nathanael Bonfim): "
read -r GPG_NAME

echo -n "Enter your email for the GPG key: "
read -r GPG_EMAIL

echo ""
echo "Generating GPG key for $GPG_NAME <$GPG_EMAIL> ..."

GPG_KEY_ID=$(gpg --batch --gen-key <<EOF 2>/dev/null | tail -1 | awk '{print $NF}'
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
)

if [ -z "$GPG_KEY_ID" ]; then
  echo -e "${RED}[x]${NC} Failed to generate GPG key"
  exit 1
fi

echo -e "${GREEN}[+]${NC} GPG key generated: $GPG_KEY_ID"

# ── Step 2: Export public key to repo ─────────────────────────

mkdir -p "$REPO_DIR/secnpmlly/keys"
gpg --armor --export "$GPG_KEY_ID" > "$REPO_DIR/secnpmlly/keys/trusted.asc"
echo -e "${GREEN}[+]${NC} Public key exported to secnpmlly/keys/trusted.asc"

# ── Step 3: Configure git signing (repo-local only) ───────────

git -C "$REPO_DIR" config --local user.signingKey "$GPG_KEY_ID"
git -C "$REPO_DIR" config --local commit.gpgSign true
git -C "$REPO_DIR" config --local tag.gpgSign true

echo -e "${GREEN}[+]${NC} Git signing configured (repo-local only)"
echo ""
echo "Done! Your private key is stored only in your GPG keyring."
echo "The public key is in secnpmlly/keys/trusted.asc (safe to commit)."
echo ""
echo "To create a signed release tag:"
echo "  git tag -s v0.4.0 -m 'Release v0.4.0'"
echo "  git push origin v0.4.0"
echo ""
