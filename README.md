# ZSH Dotfiles
Customized ZSH shell script and dotfiles for Linux and macOS development box

## Installation
```
# Backup your existing dotfiles
cp ~/.zshenv ~/.zshenv.bak

cd ~/.config
git clone https://github.com/delfianto/dotfiles.git
ln -sf ~/.config/dotfiles/zsh/.zshenv ~/.zshenv
```

## Important Environment Variables
- ZDOTDIR: Determines the directory where ZSH looks for its configuration files. By default, it is set to `~/.config/dotfiles/zsh`. This variable can be overridden to point to a different directory.
- ZSH_DEBUG_INIT: Enables debug mode for ZSH initialization. Set to `1` to enable debug mode.

## Directory Structure
- `zsh/autoload` : ZSH autoloaded functions
  - `common` : Common function helpers (list loaded functions, check function name)
  - `devtools` : Common functions for various development tools
  - `linux` : Autoloaded functions specific to Linux (in this case, Arch Linux family)
  - `macos` : Autoloaded functions specific to macOS
- `zsh/files` : ZSH scripts that will be imported by `${ZDOTDIR}/.zshrc` using `fun:zsh_import` function
  - `01_alias` : Common alias definitions, always sourced regardless of platform
  - `02_linux` : Aliases and other initialization specific to Linux
  - `02_macos` : Aliases and other initialization specific to macOS

## Note on Autoloaded Functions
Functions with name `fun:` and `cmd:` are autoloaded and can be used anywhere in the shell.
The `zsh/autoload` directory is defined as ZSH `fpath` and initialized by the `${ZDOTDIR}/.zshrc` file.

### Naming Coventions
- `fun:` intended to be used as common helpers when writing scripts or functions.
- `cmd:` intended to be executed as commands, they are automatically aliased to `kebab-cased` name for ease of access. For example, `cmd:print_path` will be aliased to `print-path`.
