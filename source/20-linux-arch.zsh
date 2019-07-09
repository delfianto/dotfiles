# File 99-arch.zsh; Arch family specific zsh setup
#
# Actually written on Manjaro, but this file should be
# compatible with any Arch-based distro out there

# Initialize zplug
fn.source '/usr/share/zsh/scripts/zplug/init.zsh'

# Import LS_Colors definition
fn.source '/usr/share/LS_COLORS/dircolors.sh'

# Wrapper function for package manager
pkg() {
if (( ${+commands[yay]} )); then
    echo -n ''
  else
    sudo pacman --noconfirm -S yay
  fi

  case ${1} in
  'chk')
    yay "${@:2}"
    ;;
  'log')
    cat /var/log/pacman.log
    ;;
  'deps')
    pactree -d 1 "${@:2}"
    ;;
  'find')
    yay -Ss "${@:2}"
    ;;
  'files')
    yay -Qlq "${@:2}"
    ;;
  'clean')
    echo 'y' | yay -Sc
    ;;
  'l' | 'ls' | 'list')
    [[ -z "${2}" ]] && yay -Q || yay -Qs ${@:2}
    ;;
  'n' | 'nf' | 'info')
    yay -Qi "${@:2}"
    ;;
  'o' | 'or' | 'orphans')
    yay -Qdtq
    ;;
  'c' | 'cl' | 'cleanup')
    pkg rm $(pkg orphans)
    ;;
  'i' | 'in' | 'install')
    yay -Sy "${@:2}"
    ;;
  'r' | 'rm' | 'remove')
    yay -R "${@:2}"
    ;;
  'u' | 'up' | 'update')
    yay -Syu
    ;;
  'purge')
    tput setaf 1 # this command could bork the system, use with care
    echo 'WARNING: Removing package with all of its unneeded dependencies'
    echo 'WARNING: THIS OPERATION CAN BE DESTRUCTIVE'
    tput sgr0

    yay -Rs "${@:2}"
    ;;
  'h' | 'help')
    echo "Usage: ${FUNCNAME[0]} <operation> [...]"
    echo "operation:"
    echo "  - chk"
    echo "  - log"
    echo "  - deps"
    echo "  - find"
    echo "  - files"
    echo "  - purge"
    echo "  - l | ls | list"
    echo "  - n | in | info"
    echo "  - o | or | orphans"
    echo "  - c | cl | cleanup"
    echo "  - i | in | install"
    echo "  - r | rm | remove"
    echo "  - u | up | update"
    ;;
  *)
    yay "${@:1}"
    ;;
  esac
}
