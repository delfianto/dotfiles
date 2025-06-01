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
