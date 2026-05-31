# secnpmlly - npm wrapper
#   npm install (standalone, lockfile exists) -> lockfile-lint + npm ci
#   npm install (standalone, no lockfile)     -> npq audit (package.json) + npm install + lockfile-lint
#   npm install <pkg(s)>                      -> npq audit + npm install + lockfile-lint
#   npm i <pkg(s)>                            -> npq audit + npm install + lockfile-lint
#   anything else                             -> pass through

npm() {
  case "$1" in
    install|i)
      if [ $# -eq 1 ]; then
        if [ -f package-lock.json ]; then
          _npm_supply_lint_lockfile || return 1
          command npm ci
        else
          _npm_supply_npq_audit_package_json npm || return 1
          command npm install && _npm_supply_lint_lockfile
        fi
      else
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
