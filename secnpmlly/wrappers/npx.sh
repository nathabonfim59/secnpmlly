# secnpmlly - npx wrapper
#   npx <pkg> -> npq audit (dry-run), prompt on failure, then exec

npx() {
  local _pkg
  _pkg=$(_npm_supply_first_pkg "$@")
  if [ -n "$_pkg" ]; then
    _npm_supply_npq_audit npm "$_pkg" || return 1
  fi
  command npx "$@"
}
