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
  if [[ -f "$1" ]]; then
    case "$1" in
    *.tar.bz2) tar xjf "$1" ;;
    *.tar.gz) tar xzf "$1" ;;
    *.bz2) bunzip2 "$1" ;;
    *.rar) unrar x "$1" ;;
    *.gz) gunzip "$1" ;;
    *.tar) tar xf "$1" ;;
    *.tbz2) tar xjf "$1" ;;
    *.tgz) tar xzf "$1" ;;
    *.zip) unzip "$1" ;;
    *.Z) uncompress "$1" ;;
    *.7z) 7z x "$1" ;;
    *) echo "'$1' cannot be extracted via ex()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Show gcc flags current cpu
gcc-flags() {
  gcc -c -Q -march=native --help=target
}

# Show iommu grouping and other hardware info.
# Very useful when running pci passthrough using vfio
iommu() {
  case "${1}" in
  's' | 'dev')
    sudo lspci -vv -s "${2}"
    ;;
  'g' | 'group')
    local iommu='/usr/bin/ls -dv /sys/kernel/iommu_groups/*'

    for group in $(eval "${iommu}"); do
      printf 'IOMMU Group %02d: \n' "${group##*/}"
      for device in ${group}/devices/*; do
        local out=$(lspci -nns "${device##*/}")
        local pci="${out%% *}" # Extract first word (pci-id)

        printf ' - '
        # Remove some of the vendor name output (shorter line)
        regexp-replace out 'Advanced Micro Devices, Inc. ' ''
        regexp-replace out 'Technology Inc. ' ''
        regexp-replace out 'Corporation ' ''

        # Combine the 'pretty print' output, exclude nvme device
        # from output processing; some pcie ssd from Adata does
        # not show any meaningful info other than 'device (rev xx)'.
        if [[ -z $(echo "${out}" | grep 'Volatile') ]]; then
          echo "${pci} ${out#*: }"
        else
          echo "${out}"
        fi
      done; echo
    done
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
    # todo: put some help text here
    echo 'Fus Ro Dah!'
    ;;
  esac
}

# Wrapper function for systemd related command.
#
# Why they have to make the command super long
# and thus so goddamn tedious to type...
sux() {
  local cmd=''
  local usr='--user'
  local fun=$funcstack[1]

  if [[ "$1" == "${usr}" ]]; then
    local arg="$2"
  else
    local arg="$1"
  fi

  case "${arg}" in
  'ls' | 'list')
    cmd='systemctl list-units --type service'
    [[ ! -z "$2" ]] && cmd="${cmd} --all"
    ;;
  'start' | 'stop' | 'restart' | 'status' | 'enable' | 'disable')
    [ ! -z "$2" ] && cmd="systemctl ${@:2}"
    ;;
  'log')
    [[ ! -z "$2" ]] && cmd="journalctl -u ${@:2}"
    ;;
  'help')
    echo "Usage: ${fun} [list] [unit-state]"
    echo "Usage: ${fun} [log|start|stop|restart] [unit-name]"
    ;;
  *)
    cmd="${fun} help"
    ;;
  esac


  if [[ "$1" == "${usr}" ]]; then
    cmd="${cmd} ${usr}"
  fi

  [[ ! -z "${cmd}" ]] && eval "${cmd}"
}

# Alias for systemd wrapper
alias scu='sux --user'
alias scx='fn.sudo sux'
