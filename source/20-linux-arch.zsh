# File 99-arch.zsh; Arch family specific zsh setup
#
# Actually written on Manjaro, but this file should be
# compatible with any Arch-based distro out there

# Set makepkg environment variables
export PKGEXT='.pkg.tar.xz'
export COMPRESSXZ=(xz -T 0 -c -z -)
export MAKEFLAGS='-j20'

# Set compiler flags
export CFLAGS='-march=native -O2 -pipe -fstack-protector-strong -fno-plt'
export CXXFLAGS="${CFLAGS}"

# Set additional cflags for building ffmpeg
export _cflags='-I/usr/include/tensorflow'

# Initialize zplug
fn.source '/usr/share/zsh/scripts/zplug/init.zsh'

# Import LS_Colors definition
fn.source '/usr/share/LS_COLORS/dircolors.sh'

# Wrapper function for package manager
pkg() {
  if (( !${+commands[yay]} )); then
    sudo pacman --noconfirm -S yay
  fi

  case ${1} in
  'logs')
    cat /var/log/pacman.log
    ;;
  'check')
    yay "${@:2}"
    ;;
  'cache')
    echo 'y' | yay -Sc
    ;;
  'clean')
    if [[ ! -z $(pkg orphans) ]]; then
      tput setaf 1 #
      echo 'WARNING: Removing all unneeded dependencies...'
      tput sgr0

      yay -Yc
    else
      echo 'No unneeded dependencies in the system.'
    fi
    ;;
  'deps')
    pactree -d 1 "${@:2}"
    ;;
  'file')
    yay -Qlq "${@:2}"
    ;;
  'find')
    yay -Ss "${@:2}"
    ;;
  'info')
    yay -Qi "${@:2}"
    ;;
  'orphans')
    yay -Qdtq
    ;;
  'l' | 'ls' | 'list')
    yay -Qs ${@:2}
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
  'd' | 'db' | 'database' )
    yay -Syy
    ;;
  *)
    yay "${@:1}"
    ;;
  esac
}
