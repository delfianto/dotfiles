# File 30-manjaro.zsh; Manjaro Linux specific zsh setup
# Also applicable to most other Arch-based Linux distro

if $(zsh_is_linux_arch); then
  # Import LS_Colors definition
  zsh_source '/usr/share/LS_COLORS/dircolors.sh'
fi
