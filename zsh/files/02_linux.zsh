# ==================================================================
# File 01_linux.zsh; linux specific alias and environment variables
# ==================================================================

# Bail out if not sourced from linux
if [[ "${OS_NAME}" != 'linux' ]]; then
  return 1
fi

# ls enhancement
alias ls="ls ${LS_ARGS}"
alias ll="ls ${LS_ARGS} -l"
alias la="ls ${LS_ARGS} -a"

# CPU clock and system monitoring
alias cpufreq='watch -n1 "cat /proc/cpuinfo | grep \"^[c]pu MHz\""'
alias hwmon='watch -n1 sensors'
alias hdmon='sudo hdsentinel'
alias dmesg='sudo dmesg -H'
alias lqctl='sudo liquidctl'

# Device info alias
alias usbdev='lsusb -tv'
alias pcidev='lspci -tv'
alias pcinfo='lspci -nnv'

# Get parameters of a kernel module
alias svm='systool -vm'

# Wrapper for running virtmanager cli
alias vsh='sudo virsh'

# Set git credentials helper
export SSH_ASKPASS="$(which ksshaskpass)"
export GIT_ASKPASS="${SSH_ASKPASS}"

# Set makepkg environment variables
export PKGEXT='.pkg.tar.zst'
export MAKEFLAGS='-j20'

# Set compiler flags
export CFLAGS='-march=native -O2 -pipe -fstack-protector-strong -fno-plt'
export CXXFLAGS="${CFLAGS}"

# Import LS_COLORS definition
zsh-in /usr/share/LS_COLORS/dircolors.sh

iommu() {
  case ${1} in
    'p' | 'pci')
      sudo lspci -vv -s ${2}
      ;;
    'g' | 'group')
      local groups='ls -dv /sys/kernel/iommu_groups/*'

      for group in $(eval "${groups}"); do
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
      echo "${1}"
      # TODO: Put some help text here
      echo 'Klaatu Barada Nikto'
      ;;
  esac
}

pkg() {
  if (( !${+commands[yay]} )); then
    echo 'Yay AUR helper is not installed'
    return 1
  fi

  case "${1}" in
    'logs')
      cat /var/log/pacman.log
      ;;
    'build')
      makepkg -sc
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
        tput setaf 1
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
      yay -R ${@:2}
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
      yay ${@:1}
      ;;
  esac
}

svc() {
  systemctl ${@:1}
}
