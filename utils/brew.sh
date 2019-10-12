#!/usr/bin/env zsh
# homebrew bootstrap script to perform batch install of formulas
# obviously, this only works on macos with functional brew.

if ! (( ${+commands[brew]} )); then
  echo 'Homebrew is not installed.'
  exit 1
fi

PACKAGES=(
  # updates shell
  zsh
  zplug
  # gnu utilities
  grep
  gnu-sed
  gnu-tar
  gnu-indent
  gnu-which
  coreutils
  findutils
  # media apps
  ffmpeg
  imagemagick
  # devtools
  git
  diff-so-fancy
  autoconf
  automake
  libtool  
  pkg-config
  postgresql
  mariadb
  python
  ruby
  node
  yarn
  go
  # other utils
  gocryptfs
  tmux
  tree
  wget
  # text editors
  nano
  neovim
)

echo 'Installing packages...'
brew install ${PACKAGES[@]}

echo 'Cleaning up...'
brew cleanup
