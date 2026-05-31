# secnpmlly helpers - shared utilities for all wrappers
# sourced by secnpmlly.sh; do not source standalone.

# ── Prompt the user on failure; default is NO (abort). ────────
_npm_supply_prompt() {
  printf '%s[?]%s Continue anyway? [y/N] ' "$(c bold_yellow)" "$(c off)"
  read -r _answer </dev/tty
  case "$_answer" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) echo 'Aborting.'; return 1 ;;
  esac
}

# ── Detect and lint the project lockfile. ─────────────────────
# Priority order: bun.lock (text) > bun.lockb (binary) > others
# bun.lock is yarn-compatible text, so we pass --type yarn for it.
_npm_supply_lint_lockfile() {
  local lockfile=''
  local lockfile_type=''

  if   [ -f package-lock.json ]; then lockfile=package-lock.json; lockfile_type='npm'
  elif [ -f bun.lock ];          then lockfile=bun.lock;          lockfile_type='yarn'
  elif [ -f pnpm-lock.yaml ];    then lockfile=pnpm-lock.yaml;    lockfile_type='npm'
  elif [ -f bun.lockb ];         then lockfile=bun.lockb;         lockfile_type=''
  elif [ -f yarn.lock ];         then lockfile=yarn.lock;         lockfile_type='yarn'
  fi

  if [ -z "$lockfile" ]; then
    printf '%s[!]%s No lockfile found - skipping lockfile-lint\n' "$(c bold_yellow)" "$(c off)"
    return 0
  fi

  local type_arg=''
  if [ -n "$lockfile_type" ]; then
    type_arg="--type $lockfile_type"
  fi

  printf '%s[i]%s Running lockfile-lint on %s ...\n' "$(c cyan)" "$(c off)" "$lockfile"
  if command lockfile-lint \
    --path "$lockfile" \
    $type_arg \
    --validate-integrity \
    --validate-package-names \
    --allowed-hosts npm \
    --allowed-schemes "https:" "file:"; then
    printf '%s[+]%s lockfile-lint passed\n' "$(c green)" "$(c off)"
    return 0
  fi

  echo ''
  printf '%s[x]%s lockfile-lint FAILED - possible supply-chain tampering detected!\n' "$(c red)" "$(c off)"
  printf '%s[x]%s Review the issues above carefully before proceeding.\n' "$(c red)" "$(c off)"
  _npm_supply_prompt
}

# ── Audit packages with npq (dry-run only). ──────────────────
_npm_supply_npq_audit() {
  local _pkg_mgr="${1:-npm}"
  shift

  printf '%s[i]%s Auditing packages with npq ...\n' "$(c cyan)" "$(c off)"
  if NPQ_PKG_MGR="$_pkg_mgr" command npq install "$@" --dry-run 2>&1; then
    printf '%s[+]%s npq audit passed\n' "$(c green)" "$(c off)"
    return 0
  fi

  echo ''
  printf '%s[x]%s npq audit FAILED - supply-chain concerns detected!\n' "$(c red)" "$(c off)"
  printf '%s[x]%s Review the issues above carefully.\n' "$(c red)" "$(c off)"
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
