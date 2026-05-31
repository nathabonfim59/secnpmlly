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
# Priority order: package-lock.json > bun.lock > pnpm-lock.yaml > yarn.lock.
_npm_supply_lint_lockfile() {
  local preferred="${1:-}"
  local lockfile=''
  local lockfile_type=''

  case "$preferred" in
    npm)
      if [ -f package-lock.json ]; then lockfile=package-lock.json; lockfile_type='npm'; fi
      ;;
    pnpm)
      if [ -f pnpm-lock.yaml ]; then lockfile=pnpm-lock.yaml; lockfile_type='pnpm'; fi
      ;;
    yarn)
      if [ -f yarn.lock ]; then lockfile=yarn.lock; lockfile_type='yarn'; fi
      ;;
    bun)
      if [ -f bun.lock ]; then
        lockfile=bun.lock; lockfile_type='bun'
      elif [ -f bun.lockb ]; then
        printf '%s[!]%s bun.lockb is binary - skipping lockfile validation. Run bun install --save-text-lockfile to create bun.lock.\n' "$(c bold_yellow)" "$(c off)"
        return 0
      fi
      ;;
    *)
      if   [ -f package-lock.json ]; then lockfile=package-lock.json; lockfile_type='npm'
      elif [ -f bun.lock ];          then lockfile=bun.lock;          lockfile_type='bun'
      elif [ -f pnpm-lock.yaml ];    then lockfile=pnpm-lock.yaml;    lockfile_type='pnpm'
      elif [ -f yarn.lock ];         then lockfile=yarn.lock;         lockfile_type='yarn'
      elif [ -f bun.lockb ];         then
        printf '%s[!]%s bun.lockb is binary - skipping lockfile validation. Run bun install --save-text-lockfile to create bun.lock.\n' "$(c bold_yellow)" "$(c off)"
        return 0
      fi
      ;;
  esac

  if [ -z "$lockfile" ]; then
    printf '%s[!]%s No lockfile found - skipping lockfile validation\n' "$(c bold_yellow)" "$(c off)"
    return 0
  fi

  local allowed_hosts='npm'
  if [ "$lockfile_type" = 'yarn' ]; then
    allowed_hosts='npm yarn'
  fi

  printf '%s[i]%s Validating %s ...\n' "$(c cyan)" "$(c off)" "$lockfile"
  # shellcheck disable=SC2086 - allowed_hosts is an intentional list of CLI args
  if command node "$_SECNPMLLY_DIR/validators/lockfile.js" \
    --path "$lockfile" \
    --type "$lockfile_type" \
    --validate-https \
    --validate-integrity \
    --validate-package-names \
    --allowed-hosts $allowed_hosts; then
    printf '%s[+]%s lockfile validation passed\n' "$(c green)" "$(c off)"
    return 0
  fi

  echo ''
  printf '%s[!]%s lockfile validation found entries that do not match the policy.\n' "$(c bold_yellow)" "$(c off)"
  printf '%s[!]%s Review the findings above before proceeding.\n' "$(c bold_yellow)" "$(c off)"
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

# ── Audit all deps from package.json before standalone installs. ──
# Reads deps as data via JSON.parse; no code in package.json is executed.
_npm_supply_npq_audit_package_json() {
  local _pkg_mgr="${1:-npm}"

  [ -f package.json ] || return 0

  local _pkgs
  _pkgs=$(node -e "
const p = JSON.parse(require('fs').readFileSync('./package.json', 'utf8'));
const d = Object.keys(p.dependencies || {}).concat(Object.keys(p.devDependencies || {}));
if (d.length) process.stdout.write(d.join(' '));
" 2>/dev/null)

  [ -n "$_pkgs" ] || return 0

  # shellcheck disable=SC2086 - word-split intentional: each package name is a separate arg
  _npm_supply_npq_audit "$_pkg_mgr" $_pkgs
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
