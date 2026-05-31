# secnpmlly — Supply-chain protection for npm/pnpm/bun
#
# This is the entry point. Source it from your shell rc:
#   [ -f ~/.local/share/secnpmlly/secnpmlly.sh ] && source ~/.local/share/secnpmlly/secnpmlly.sh

# Guard against double-sourcing
if [ -n "${_SECNPMLLY_LOADED:-}" ]; then
  return 0 2>/dev/null || true
fi
_SECNPMLLY_LOADED=1

_SECNPMLLY_DIR="${_SECNPMLLY_DIR:-$HOME/.local/share/secnpmlly}"

# ── Version & CLI ──────────────────────────────────────────────
secnpmlly() {
  local _ver
  _ver=$(cat "$_SECNPMLLY_DIR/version" 2>/dev/null || echo "unknown")
  case "${1:-}" in
    version|--version|-v)
      printf '%ssecnpmlly %s%s\n' "$(c bold_cyan)" "$_ver" "$(c off)"
      ;;
    help|--help|-h)
      printf '%ssecnpmlly %s%s\n' "$(c bold_cyan)" "$_ver" "$(c off)"
      echo ""
      echo "Usage: secnpmlly <command>"
      echo ""
      echo "Commands:"
      echo "  version   Show version"
      echo "  status    Show which wrappers are active"
      echo "  update    Verify and install the latest signed release"
      echo "  help      Show this help"
      echo ""
      echo "Wrappers are loaded automatically when this file is sourced."
      echo "Managed commands: npm, npx, pnpm, pnpx, bun, bunx"
      ;;
    status)
      printf '%ssecnpmlly %s%s\n' "$(c bold_cyan)" "$_ver" "$(c off)"
      echo ""
      echo "Active wrappers:"
      type npm  2>/dev/null | head -1 | sed 's/^/  /'
      type npx  2>/dev/null | head -1 | sed 's/^/  /'
      type pnpm 2>/dev/null | head -1 | sed 's/^/  /'
      type pnpx 2>/dev/null | head -1 | sed 's/^/  /'
      type bun  2>/dev/null | head -1 | sed 's/^/  /'
      type bunx 2>/dev/null | head -1 | sed 's/^/  /'
      ;;
    update)
      # Delegate to the CLI binary (handles GPG verification)
      command secnpmlly update
      ;;
    *)
      printf '%ssecnpmlly %s%s\n' "$(c bold_cyan)" "$_ver" "$(c off)"
      echo "Run 'secnpmlly help' for more information."
      ;;
  esac
}

# ── Load modules ───────────────────────────────────────────────
source "$_SECNPMLLY_DIR/colors.sh"
source "$_SECNPMLLY_DIR/helpers.sh"
for _wrapper in "$_SECNPMLLY_DIR"/wrappers/*.sh; do
  source "$_wrapper"
done
unset _wrapper
