# secnpmlly - npm wrapper
#   npm install                              -> npq audit (package.json) + install + lockfile check
#   npm install <pkg(s)>                      -> npq audit + npm install + lockfile-lint
#   npm i <pkg(s)>                            -> npq audit + npm install + lockfile-lint
#   anything else                             -> pass through

npm() {
  case "$1" in
    install|i)
      if [ $# -eq 1 ]; then
        _npm_supply_npq_audit_package_json npm || return 1
        if [ -f package-lock.json ]; then
          _npm_supply_lint_lockfile npm || return 1
          command npm ci
        else
          command npm install && _npm_supply_lint_lockfile npm
        fi
      else
        shift
        _npm_supply_npq_audit npm "$@" || return 1
        command npm install "$@" && _npm_supply_lint_lockfile npm
      fi
      ;;
    *)
      command npm "$@"
      ;;
  esac
}
