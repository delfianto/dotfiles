#!/bin/zsh
# File 01_linux; linux specific alias and environment variables

# CPU clock and system monitoring
alias hdmon="sudo hdsentinel"
alias hwmon="watch -n1 sensors"

# Device info alias
alias usbdev="lsusb -tv"
alias pcidev="lspci -tv"

# System management
alias dmesg="sudo dmesg -H"
alias dracut="sudo dracut"
alias pacman="sudo pacman"

# Set git credentials helper
export SSH_ASKPASS="$(which ksshaskpass)"
export GIT_ASKPASS="$SSH_ASKPASS"

# Set makepkg environment variables
export PKGEXT=".pkg.tar.zst"
export MAKEFLAGS="-j$(($(nproc)+1))"

# Set compiler flags
export CFLAGS="-march=native -O2 -pipe -fstack-protector-strong -fno-plt"
export CXXFLAGS="$CFLAGS"
