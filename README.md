# ZSH Dotfiles
Customized ZSH shell script and dotfiles for Linux and macOS development box

## Installation
```
cd ~/.config
git clone https://github.com/delfianto/dotfiles.git
ln -s ~/.config/dotfiles/zsh/.zshenv ~/.zshenv
```

## Directory Structure
- `fpath` : custom ZSH functions
  - `func` : function helpers (list loaded functions, check function name)
  - `sys` : system helpers (get compiler flags, os type, ls variants)
  - `zsh-in` : import external shell script
  - `zsh-rc` : import shell script in `${ZDOTDIR}/files/${FILE_NAME}.zsh`
- `files` : custom ZSH scripts, to be imported using `zsh-rc`
  - `00_utils` : common utility functions, always sourced regardless of platform
  - `01_alias` : common alias definitions, always sourced regardless of platform
  - `02_linux` : linux specific stuff, some functions are tailored specifically for Arch Linux family
  - `02_macos` : macOS specific stull, homebrew checking, service start/stop from CLI
  - `03_devel` : common function to setup development environment
