# File zshrd-linux.zsh; Manjaro Linux specific zsh setup
# Also applicable to most other Arch-based Linux distro

# Set git credentials helper
export SSH_ASKPASS="$(which ksshaskpass)"
export GIT_ASKPASS="${SSH_ASKPASS}"

if [[ $(fn.os-like) == 'arch' ]]; then
  # Initialize zplug
  fn.source '/usr/share/zsh/scripts/zplug/init.zsh'

  # Import LS_Colors definition
  fn.source '/usr/share/LS_COLORS/dircolors.sh'
fi
