#!/usr/bin/env zsh
# homebrew bootstrap script to perform batch install of formulas
# obviously, this only works on macos with functional brew.

if ! (( ${+commands[brew]} )); then
  echo 'Homebrew is not installed.'
  exit 1
fi

PACKAGES=(
  zplug
  zsh
  git
  grep
  gnu-sed
  gnu-tar
  gnu-indent
  gnu-which
  coreutils
  findutils
  autoconf
  automake
  libtool
  ffmpeg
  imagemagick
  diff-so-fancy
  npm
  yarn
  pkg-config
  postgresql
  mariadb
  python
  tmux
  tree
  nano
  neovim
  wget
)

echo 'Installing packages...'
brew install ${PACKAGES[@]}

echo 'Cleaning up...'
brew cleanup
