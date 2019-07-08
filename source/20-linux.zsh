# File 99-linux.zsh; Linux specific zsh setup
#
# This file should be applicable to most of Linux distribution, any
# other distro specific script should be placed in (os-family).zsh

if [[ "${OS_NAME}" != 'linux' ]]; then
  return 1
else
  fn.source "20-${OS_NAME}-${OS_LIKE}.zsh"
fi

# Set git credentials helper
export SSH_ASKPASS="$(which ksshaskpass)"
export GIT_ASKPASS="${SSH_ASKPASS}"

# Hardware acceleration on Firefox
export MOZ_ACCELERATED=1
export MOZ_WEBRENDER=1

# CPU clock and system monitoring
alias cpufreq='watch -n1 "cat /proc/cpuinfo | grep \"^[c]pu MHz\""'
alias hwmon='watch -n1 sensors'

# Device info alias
alias usbdev='lsusb -tv'
alias pcidev='lspci -tv'
alias pcinfo='lspci -nnv'

# Get parameters of a kernel module
alias svm='systool -vm'

# Wrapper for running virtmanager cli
alias vsh='sudo virsh'

# ex - archive extractor
# usage: ex <file>
ex() {
  if [ -f $1 ]; then
    case $1 in
    *.tar.bz2) tar xjf $1 ;;
    *.tar.gz) tar xzf $1 ;;
    *.bz2) bunzip2 $1 ;;
    *.rar) unrar x $1 ;;
    *.gz) gunzip $1 ;;
    *.tar) tar xf $1 ;;
    *.tbz2) tar xjf $1 ;;
    *.tgz) tar xzf $1 ;;
    *.zip) unzip $1 ;;
    *.Z) uncompress $1 ;;
    *.7z) 7z x $1 ;;
    *) echo "'$1' cannot be extracted via ex()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Show iommu grouping and other hardware info.
# Very useful when running pci passthrough using vfio
iommu() {
  case "${1}" in
  'g' | 'group')
    for d in /sys/kernel/iommu_groups/*/devices/*; do
      n=${d#*/iommu_groups/*}
      n=${n%%/*}
      printf 'IOMMU Group %02d ' "$n"
      lspci -nns "${d##*/}"
    done | sort -V
    ;;
  'u' | 'usb')
    for usb_ctrl in $(find /sys/bus/usb/devices/usb* -maxdepth 0 -type l); do
      pci_path="$(dirname "$(realpath "${usb_ctrl}")")"
      echo "Bus $(cat "${usb_ctrl}/busnum") --> $(basename $pci_path)
          (IOMMU group $(basename $(realpath $pci_path/iommu_group)))"
      lsusb -s "$(cat "${usb_ctrl}/busnum"):"
      echo
    done
    ;;
  *)
    # todo: wrote something here
    echo 'Fus Ro Dah!'
    ;;
  esac
}

# Wrapper function for systemd related command, since those things
# is super goddamn tedious to type thus we name the function SUX!
sux() {
  local cmd=''

  case "$1" in
  'ls' | 'list')
    cmd='systemctl list-units --no-pager --type service'
    [[ ! -z "$2" ]] && cmd="${cmd} --all"
    ;;
  'start' | 'stop' | 'restart' | 'status' | 'enable' | 'disable')
    [ ! -z "$2" ] && cmd="sudo systemctl --no-pager $1 $2"
    ;;
  'log')
    [[ ! -z "$2" ]] && cmd="journalctl --no-pager -u $2"
    ;;
  'help')
    echo "Usage: ${FUNCNAME[0]} [list] [unit-state]"
    echo "Usage: ${FUNCNAME[0]} [log|start|stop|restart] [unit-name]"
    ;;
  *)
    cmd="${FUNCNAME[0]} help"
    ;;
  esac

  [[ ! -z "${cmd}" ]] && "${cmd}"
}
