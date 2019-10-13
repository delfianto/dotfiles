# File 20-linux-arch.zsh; Arch family specific zsh setup
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

# Initialize zplug
fn.source '/usr/share/zsh/scripts/zplug/init.zsh'

# Import LS_Colors definition
fn.source '/usr/share/LS_COLORS/dircolors.sh'

# Wrapper for default system java, in case we need to bypass sdkman.
jvm() {
  local jvm_home=$(archlinux-java get)

  if [[ -z "${jvm_home}" ]]; then
    echo 'There is no defined Java VM environment on the system.'
    echo 'Run [ archlinux-java set ] to configure your system JVM.'
    exit 1
  fi

  GDK_SCALE=2 JAVA_HOME="/usr/lib/jvm/${jvm_home}"
  "${JAVA_HOME}/bin/java" "${@:1}"
}

# Wrapper function for package manager
pkg() {
  if (( !${+commands[yay]} )); then
    sudo pacman --noconfirm -S yay
  fi

  case "$1" in
  'logs')
    cat /var/log/pacman.log
    ;;
  'build')
    makepkg -sic
    ;;
  'check')
    yay "${@:2}"
    ;;
  'clean')
    echo 'y' | yay -Sc
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
  'stat')
    yay -Ps
    ;;
  'orphan')
    yay -Qdtq
    ;;
  'nodeps')
    if [[ ! -z $(pkg orphan) ]]; then
      tput setaf 1 #
      echo 'WARNING: Removing all unneeded dependencies...'
      tput sgr0

      yay -Yc
    else
      echo 'No unneeded dependencies in the system.'
    fi
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
  'u' | 'up' | 'upgrade')
    yay -Syu
    ;;
  's' | 'sy' | 'update' )
    yay -Syy
    ;;
  'q' | 'qu' | 'quiet')
    yay --editmenu --nocleanmenu --nodiffmenu --noeditmenu --noremovemake --save
    ;;
  *)
    yay "${@:1}"
    ;;
  esac
}
