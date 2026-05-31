# secnpmlly - bun wrappers
#   bun install      -> bun install --frozen-lockfile + lockfile-lint
#   bun add <pkg(s)> -> npq audit + bun add + lockfile-lint
#   bun x <pkg>      -> npq audit (dry-run) + exec
#   bunx <pkg>       -> npq audit (dry-run) + exec
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

bunx() {
  local _pkg
  _pkg=$(_npm_supply_first_pkg "$@")
  if [ -n "$_pkg" ]; then
    _npm_supply_npq_audit bun "$_pkg" || return 1
  fi
  command bunx "$@"
}
