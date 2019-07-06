# File zshrd-linux.zsh; Manjaro Linux specific zsh setup
# Also applicable to most other Arch-based Linux distro

# Set git credentials helper
export GIT_ASKPASS="${SSH_ASKPASS}"

if $(zsh_is_linux_arch); then
  # Initialize zplug
  zsh_source '/usr/share/zsh/scripts/zplug/init.zsh'

  # Import LS_Colors definition
  zsh_source '/usr/share/LS_COLORS/dircolors.sh'
fi
