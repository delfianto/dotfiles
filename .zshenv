# File .zshenv; zsh environment config
# Based on https://github.com/romkatv/dotfiles-public/blob/master/.zshenv

export ZSH_TRACE="${ZSH_TRACE:-false}"
export ZSH_TIMER="${ZSH_TIMER:-false}"

# Set zsh dotfile location and zplug home
export ZDOTDIR="${ZDOTDIR:-"${HOME}/.config/dotfiles"}"
export ZPLUG_HOME="${ZDOTDIR}/zplug"
export ZPLUG_LOADFILE="${ZPLUG_HOME}/packages.zsh"

# Don't keep duplicates and ignore specific sets of command from history
# https://unix.stackexchange.com/questions/18212/bash-history-ignoredups-and-erasedups-setting-conflict-with-common-history
export HISTIGNORE="&:history*:rm*:[c]ls*:[bf]g*:exit*:pwd*:clear*:mount*:umount*:vol*:encfs*:cfs*:[ \t]*"
export HISTFILE="${ZDOTDIR}/.histfile"
export HISTSIZE=1000
export SAVEHIST=1000

export EDITOR='/usr/bin/nano'
export PAGER='less'

# This affects every invocation of `less`.
#
#   -i   case-insensitive search unless search string contains uppercase letters
#   -R   color
#   -F   exit if there is less than one page of content
#   -X   keep content on screen after exit
#   -M   show more info at the bottom prompt line
#   -x4  tabs are 4 instead of 8
export LESS='-iRFXMx4'

if (( $#commands[(i)lesspipe(|.sh)] )); then
  export LESSOPEN="| /usr/bin/env ${commands}[(i)lesspipe(|.sh)] %s 2>&-"
fi
