# File zshrd-linux.zsh; Manjaro Linux specific zsh setup
# Also applicable to most other Arch-based Linux distro

if $(zsh_is_linux_arch); then
  # Initialzie powerlevel10k
  zsh_source '/usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme'

  # Import LS_Colors definition
  zsh_source '/usr/share/LS_COLORS/dircolors.sh'
fi
