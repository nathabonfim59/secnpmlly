# secnpmlly colors — TTY-aware color output
# sourced by secnpmlly.sh and apply-protections.sh; do not source standalone.

# Returns the ANSI escape code for a named color when stdout is a TTY.
# Returns empty string when not a TTY (pipes, CI, redirects).
#
# Usage:
#   echo "$(c green)success$(c off) message"
#   printf '%s[+]%s done\n' "$(c green)" "$(c off)"
#
# Named colors (standard SGR codes — works with any terminal theme):
#   black red green yellow blue magenta cyan white
#   bold_black bold_red bold_green bold_yellow bold_blue bold_magenta bold_cyan bold_white
#   off  (reset all)
_secnpmlly_is_tty() {
  [ -t 1 ]
}

c() {
  _secnpmlly_is_tty || return 0

  case "$1" in
    # Standard colors (0;3x) — these pick up the user's terminal theme
    black)        printf '\033[0;30m' ;;
    red)          printf '\033[0;31m' ;;
    green)        printf '\033[0;32m' ;;
    yellow)       printf '\033[0;33m' ;;
    blue)         printf '\033[0;34m' ;;
    magenta)      printf '\033[0;35m' ;;
    cyan)         printf '\033[0;36m' ;;
    white)        printf '\033[0;37m' ;;
    # Bold / bright variants (1;3x)
    bold_black)   printf '\033[1;30m' ;;
    bold_red)     printf '\033[1;31m' ;;
    bold_green)   printf '\033[1;32m' ;;
    bold_yellow)  printf '\033[1;33m' ;;
    bold_blue)    printf '\033[1;34m' ;;
    bold_magenta) printf '\033[1;35m' ;;
    bold_cyan)    printf '\033[1;36m' ;;
    bold_white)   printf '\033[1;37m' ;;
    # Reset
    off|reset)    printf '\033[0m' ;;
    *)            return 1 ;;
  esac
}
