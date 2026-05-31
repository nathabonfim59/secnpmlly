# secnpmlly - npm wrapper
#   npm install (standalone, lockfile exists) -> npm ci  + lockfile-lint
#   npm install (standalone, no lockfile)     -> npm install + lockfile-lint
#   npm install <pkg(s)>                      -> npq audit + npm install + lockfile-lint
#   npm i <pkg(s)>                            -> npq audit + npm install + lockfile-lint
#   anything else                             -> pass through

npm() {
  case "$1" in
    install|i)
      if [ $# -eq 1 ]; then
        if [ -f package-lock.json ]; then
          command npm ci && _npm_supply_lint_lockfile
        else
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
