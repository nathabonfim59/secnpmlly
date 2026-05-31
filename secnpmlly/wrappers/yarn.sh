# secnpmlly - yarn wrapper
#   yarn install -> npq audit (package.json) + frozen install + lockfile check
#   yarn add <pkg(s)> -> npq audit + yarn add + lockfile check
#   yarn dlx <pkg>    -> npq audit (dry-run) + exec
#   anything else     -> pass through

_npm_supply_yarn_frozen_arg() {
  local _ver
  local _major

  _ver=$(command yarn --version 2>/dev/null || echo "")
  _major=${_ver%%.*}

  case "$_major" in
    ""|*[!0-9]*|0|1) echo "--frozen-lockfile" ;;
    *) echo "--immutable" ;;
  esac
}

yarn() {
  case "$1" in
    install)
      if [ $# -eq 1 ]; then
        _npm_supply_npq_audit_package_json yarn || return 1
        if [ -f yarn.lock ]; then
          _npm_supply_lint_lockfile yarn || return 1
          command yarn install "$(_npm_supply_yarn_frozen_arg)"
        else
          command yarn install && _npm_supply_lint_lockfile yarn
        fi
      else
        command yarn "$@"
      fi
      ;;
    add)
      shift
      _npm_supply_npq_audit yarn "$@" || return 1
      command yarn add "$@" && _npm_supply_lint_lockfile yarn
      ;;
    dlx)
      local _pkg
      _pkg=$(_npm_supply_first_pkg "${@:2}")
      if [ -n "$_pkg" ]; then
        _npm_supply_npq_audit yarn "$_pkg" || return 1
      fi
      command yarn "$@"
      ;;
    *)
      command yarn "$@"
      ;;
  esac
}
