# secnpmlly helpers — shared utilities for all wrappers
# sourced by secnpmlly.sh; do not source standalone.

# ── Prompt the user on failure; default is NO (abort). ────────
_npm_supply_prompt() {
  printf '\033[1;33m[?]\033[0m Continue anyway? [y/N] '
  read -r _answer
  case "$_answer" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) echo 'Aborting.'; return 1 ;;
  esac
}

# ── Detect and lint the project lockfile. ─────────────────────
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

# ── Audit packages with npq (dry-run only). ──────────────────
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

# ── Extract the first non-flag argument (package name). ───────
_npm_supply_first_pkg() {
  for _arg in "$@"; do
    case "$_arg" in
      -*) continue ;;
      *) echo "$_arg"; return ;;
    esac
  done
}
