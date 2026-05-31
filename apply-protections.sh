#!/usr/bin/env bash
#
# apply-protections.sh — Harden all Node/Bun/pnpm package managers against supply-chain attacks.
#
# Protections applied:
#   1. ~/.npmrc            — min-release-age, ignore-scripts, allow-git=none
#   2. ~/.bunconfig.toml   — minimumReleaseAge, ignore-scripts
#   3. ~/.config/pnpm/config.yaml — minimumReleaseAge, blockExoticSubdeps, trustPolicy
#   4. npm install -g npq  — audit packages before install
#   5. npm install -g lockfile-lint — verify lockfile integrity after install
#   6. Shell wrappers — frozen installs, npq audits, lockfile-lint checks
#
# Run:  bash apply-protections.sh
#

set -euo pipefail

# ---------- helpers ----------

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
die()   { echo -e "${RED}[x]${NC} $*"; exit 1; }

ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    info "Created directory $dir"
  fi
}

# ---------- 1. npm (~/.npmrc) ----------

apply_npm() {
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
    info "npm  -> ${npmrc} updated"
  else
    info "npm  -> ${npmrc} already correct"
  fi
}

# ---------- 2. bun (~/.bunconfig.toml) ----------

apply_bun() {
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
    info "bun  -> ${bunconf} written"
  else
    info "bun  -> ${bunconf} already correct"
  fi
}

# ---------- 3. pnpm (~/.config/pnpm/config.yaml) ----------

apply_pnpm() {
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
    info "pnpm -> ${conf} written"
  else
    info "pnpm -> ${conf} already correct"
  fi
}

# ---------- 4. Shell wrappers ----------

MARKER='# >>> npm-supply-protect >>>'
MARKER_END='# <<< npm-supply-protect <<<'

# Use a heredoc to avoid escaping nightmares — the single-quoted 'SNIPPET'
# prevents any variable expansion inside.
generate_snippet() {
  cat << 'SNIPPET'
# >>> npm-supply-protect >>>

# ── Shared helpers ──────────────────────────────────────────────

# Prompt the user on failure; default is NO (abort).
_npm_supply_prompt() {
  printf '\033[1;33m[?]\033[0m Continue anyway? [y/N] '
  read -r _answer
  case "$_answer" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) echo 'Aborting.'; return 1 ;;
  esac
}

# Detect and lint the project lockfile.
_npm_supply_lint_lockfile() {
  local lockfile=''
  if   [ -f package-lock.json ]; then lockfile=package-lock.json
  elif [ -f pnpm-lock.yaml ];    then lockfile=pnpm-lock.yaml
  elif [ -f bun.lockb ];         then lockfile=bun.lockb
  elif [ -f yarn.lock ];         then lockfile=yarn.lock
  fi

  if [ -z "$lockfile" ]; then
    echo '\033[1;33m[!]\033[0m No lockfile found - skipping lockfile-lint'
    return 0
  fi

  echo '\033[0;36m[i]\033[0m Running lockfile-lint on '"$lockfile"' ...'
  if command lockfile-lint \
    --path "$lockfile" \
    --validate-https \
    --validate-integrity \
    --validate-package-names \
    --allowed-hosts npm \
    --allowed-schemes "https:" "file:"; then
    echo '\033[0;32m[+]\033[0m lockfile-lint passed'
    return 0
  fi

  echo ''
  echo '\033[0;31m[x]\033[0m lockfile-lint FAILED - possible supply-chain tampering detected!'
  echo '\033[0;31m[x]\033[0m Review the issues above carefully before proceeding.'
  _npm_supply_prompt
}

# Audit one or more packages with npq (dry-run only).
# Returns 0 if npq is happy, 1 otherwise.
_npm_supply_npq_audit() {
  local _pkg_mgr="${1:-npm}"
  shift

  echo '\033[0;36m[i]\033[0m Auditing packages with npq ...'
  if NPQ_PKG_MGR="$_pkg_mgr" command npq install "$@" --dry-run 2>&1; then
    echo '\033[0;32m[+]\033[0m npq audit passed'
    return 0
  fi

  echo ''
  echo '\033[0;31m[x]\033[0m npq audit FAILED - supply-chain concerns detected!'
  echo '\033[0;31m[x]\033[0m Review the issues above carefully.'
  _npm_supply_prompt
}

# Extract the first non-flag argument (package name) from a command line.
_npm_supply_first_pkg() {
  for _arg in "$@"; do
    case "$_arg" in
      -*) continue ;;
      *) echo "$_arg"; return ;;
    esac
  done
}

# ── npm wrapper ─────────────────────────────────────────────────
#   npm install          -> npm ci  + lockfile-lint
#   npm install <pkg(s)> -> npq audit + npm install + lockfile-lint
#   npm i <pkg(s)>       -> npq audit + npm install + lockfile-lint
#   anything else        -> pass through
npm() {
  case "$1" in
    install|i)
      if [ $# -eq 1 ]; then
        # Standalone "npm install" -> npm ci + lockfile-lint
        command npm ci && _npm_supply_lint_lockfile
      else
        # "npm install <pkg ...>" -> audit with npq, then install, then lint
        shift
        _npm_supply_npq_audit npm "$@" || return 1
        command npm install "$@" && _npm_supply_lint_lockfile
      fi
      ;;
    *)
      command npm "$@"
      ;;
  esac
}

# ── npx wrapper ─────────────────────────────────────────────────
#   npx <pkg> -> npq audit (dry-run), prompt on failure, then exec
npx() {
  local _pkg
  _pkg=$(_npm_supply_first_pkg "$@")
  if [ -n "$_pkg" ]; then
    _npm_supply_npq_audit npm "$_pkg" || return 1
  fi
  command npx "$@"
}

# ── pnpm wrapper ────────────────────────────────────────────────
#   pnpm install      -> pnpm install --frozen-lockfile + lockfile-lint
#   pnpm add <pkg(s)> -> npq audit + pnpm add + lockfile-lint
#   pnpm dlx <pkg>    -> npq audit (dry-run) + exec
#   anything else     -> pass through
pnpm() {
  case "$1" in
    install)
      if [ $# -eq 1 ]; then
        command pnpm install --frozen-lockfile && _npm_supply_lint_lockfile
      else
        shift
        _npm_supply_npq_audit pnpm "$@" || return 1
        command pnpm install "$@" && _npm_supply_lint_lockfile
      fi
      ;;
    add)
      shift
      _npm_supply_npq_audit pnpm "$@" || return 1
      command pnpm add "$@" && _npm_supply_lint_lockfile
      ;;
    dlx)
      local _pkg
      _pkg=$(_npm_supply_first_pkg "${@:2}")
      if [ -n "$_pkg" ]; then
        _npm_supply_npq_audit pnpm "$_pkg" || return 1
      fi
      command pnpm "$@"
      ;;
    *)
      command pnpm "$@"
      ;;
  esac
}

# ── pnpx wrapper ────────────────────────────────────────────────
pnpx() {
  local _pkg
  _pkg=$(_npm_supply_first_pkg "$@")
  if [ -n "$_pkg" ]; then
    _npm_supply_npq_audit pnpm "$_pkg" || return 1
  fi
  command pnpx "$@"
}

# ── bun wrapper ─────────────────────────────────────────────────
#   bun install      -> bun install --frozen-lockfile + lockfile-lint
#   bun add <pkg(s)> -> npq audit + bun add + lockfile-lint
#   bun x <pkg>      -> npq audit (dry-run) + exec
#   anything else    -> pass through
bun() {
  case "$1" in
    install)
      if [ $# -eq 1 ]; then
        command bun install --frozen-lockfile && _npm_supply_lint_lockfile
      else
        shift
        _npm_supply_npq_audit bun "$@" || return 1
        command bun install "$@" && _npm_supply_lint_lockfile
      fi
      ;;
    add)
      shift
      _npm_supply_npq_audit bun "$@" || return 1
      command bun add "$@" && _npm_supply_lint_lockfile
      ;;
    x)
      local _pkg
      _pkg=$(_npm_supply_first_pkg "${@:2}")
      if [ -n "$_pkg" ]; then
        _npm_supply_npq_audit bun "$_pkg" || return 1
      fi
      command bun "$@"
      ;;
    *)
      command bun "$@"
      ;;
  esac
}

# ── bunx wrapper ────────────────────────────────────────────────
bunx() {
  local _pkg
  _pkg=$(_npm_supply_first_pkg "$@")
  if [ -n "$_pkg" ]; then
    _npm_supply_npq_audit bun "$_pkg" || return 1
  fi
  command bunx "$@"
}

# <<< npm-supply-protect <<<
SNIPPET
}

SHELL_SNIPPET=$(generate_snippet)

apply_aliases() {
  local rc_files=()
  for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
    rc_files+=("$rc")
  done

  local shell_name
  shell_name=$(basename "${SHELL:-/bin/bash}")

  for rc in "${rc_files[@]}"; do
    local base
    base=$(basename "$rc")

    if [[ ! -f "$rc" ]]; then
      if [[ "$base" == ".${shell_name}rc" ]]; then
        touch "$rc"
        info "Created $rc"
      else
        continue
      fi
    fi

    if grep -qF "$MARKER" "$rc" 2>/dev/null; then
      info "aliases -> ${rc} already patched"
      continue
    fi

    printf '\n%s\n' "$SHELL_SNIPPET" >> "$rc"
    info "aliases -> ${rc} updated"
  done
}

# ---------- 5. Global tools ----------

apply_npq() {
  if command -v npq &>/dev/null; then
    info "npq  -> already installed ($(npq --version 2>/dev/null || echo 'unknown version'))"
  else
    info "npq  -> installing globally ..."
    npm install -g npq
    info "npq  -> installed"
  fi
}

apply_lockfile_lint() {
  if command -v lockfile-lint &>/dev/null; then
    info "lockfile-lint -> already installed ($(lockfile-lint --version 2>/dev/null || echo 'unknown version'))"
  else
    info "lockfile-lint -> installing globally ..."
    npm install -g lockfile-lint
    info "lockfile-lint -> installed"
  fi
}

# ---------- main ----------

echo ""
echo "========================================"
echo "  npm Supply-Chain Protection Setup"
echo "========================================"
echo ""

apply_npm
apply_bun
apply_pnpm
apply_npq
apply_lockfile_lint

echo ""
echo -e "${GREEN}All protections applied.${NC}"
echo ""
apply_aliases

echo ""
echo -e "${YELLOW}Reload your shell (source ~/.bashrc or ~/.zshrc) to activate wrappers.${NC}"
echo ""
echo "What gets intercepted:"
echo ""
echo "  Command                       What actually runs"
echo "  ────────────────────────────  ────────────────────────────────────────────"
echo "  npm install                   npm ci  + lockfile-lint"
echo "  npm install <pkg>             npq audit -> npm install <pkg> + lockfile-lint"
echo "  npm i <pkg>                   npq audit -> npm install <pkg> + lockfile-lint"
echo "  npx <pkg>                     npq audit -> npx <pkg>"
echo "  pnpm install                  pnpm install --frozen-lockfile + lockfile-lint"
echo "  pnpm add <pkg>                npq audit -> pnpm add <pkg> + lockfile-lint"
echo "  pnpm dlx <pkg>                npq audit -> pnpm dlx <pkg>"
echo "  pnpx <pkg>                    npq audit -> pnpx <pkg>"
echo "  bun install                   bun install --frozen-lockfile + lockfile-lint"
echo "  bun add <pkg>                 npq audit -> bun add <pkg> + lockfile-lint"
echo "  bun x <pkg>                   npq audit -> bun x <pkg>"
echo "  bunx <pkg>                    npq audit -> bunx <pkg>"
echo ""
echo "  On npq or lockfile-lint failure, you are prompted [y/N] (default: abort)."
echo ""
