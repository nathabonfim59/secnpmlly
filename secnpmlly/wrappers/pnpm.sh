# secnpmlly - pnpm wrappers
#   pnpm install          -> npq audit (package.json) + install + lockfile check
#   pnpm add <pkg(s)> -> npq audit + pnpm add + lockfile-lint
#   pnpm dlx <pkg>    -> npq audit (dry-run) + exec
#   pnpx <pkg>        -> npq audit (dry-run) + exec
#   anything else     -> pass through

pnpm() {
  case "$1" in
    install)
      if [ $# -eq 1 ]; then
        _npm_supply_npq_audit_package_json pnpm || return 1
        if [ -f pnpm-lock.yaml ]; then
          _npm_supply_lint_lockfile || return 1
          command pnpm install --frozen-lockfile
        else
          _npm_supply_npq_audit_package_json pnpm || return 1
          command pnpm install && _npm_supply_lint_lockfile
        fi
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

pnpx() {
  local _pkg
  _pkg=$(_npm_supply_first_pkg "$@")
  if [ -n "$_pkg" ]; then
    _npm_supply_npq_audit pnpm "$_pkg" || return 1
  fi
  command pnpx "$@"
}
