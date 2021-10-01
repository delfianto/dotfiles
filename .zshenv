# File .zshenv; zsh environment config
# Based on https://github.com/romkatv/dotfiles-public/blob/master/.zshenv

# Set zsh dotfile location
export ZDOTDIR="${ZDOTDIR:-"${HOME}/.config/dotfiles"}"

# Don't keep duplicates and ignore specific sets of command from history
# https://unix.stackexchange.com/questions/18212/bash-history-ignoredups-and-erasedups-setting-conflict-with-common-history
export HISTIGNORE="&:history*:[sudo ]rm*:[c]ls*:[bf]g*:exit*:pwd*:clear*:mount*:umount*:vol*:encfs*:cfs*:[ \t]*"
export HISTFILE="${ZDOTDIR}/.zsh_history"
export HISTSIZE=1000
export SAVEHIST=1000

export EDITOR='/usr/bin/nano'
export VISUAL='/usr/bin/code'
export PAGER='less'

# This affects every invocation of `less`.
#   -i   case-insensitive search unless search string contains uppercase letters
#   -R   color
#   -F   exit if there is less than one page of content
#   -X   keep content on screen after exit
#   -M   show more info at the bottom prompt line
#   -x4  tabs are 4 instead of 8
export LESS='-iRFXMx4'

# Color man pages
export LESS_TERMCAP_mb=$'\E[01;32m'
export LESS_TERMCAP_md=$'\E[01;32m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;47;34m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;36m'

if (( $#commands[(i)lesspipe(|.sh)] )); then
  export LESSOPEN="| /usr/bin/env ${commands}[(i)lesspipe(|.sh)] %s 2>&-"
fi

export LS_ARGS='--color=auto --group-directories-first -hFX'
