# File .zshenv; zsh environment config

# --- Set zsh dotfile location ---
export ZDOTDIR=${ZDOTDIR:-"${HOME}/.config/dotfiles/zsh"}

# --- Don't keep duplicates and ignore specific sets of command from history ---
# https://unix.stackexchange.com/questions/18212/bash-history-ignoredups-and-erasedups-setting-conflict-with-common-history
export HISTIGNORE="&:history*:[sudo ]rm*:[c]ls*:[bf]g*:exit*:pwd*:clear*:mount*:umount*:vol*:encfs*:cfs*:[ \t]*"
export HISTFILE="${HISTFILE:-${ZDOTDIR}/.zsh_history}"
export HISTTIMEFORMAT="%F %T "
export HISTSIZE="5000"
export SAVEHIST="5000"

export EDITOR=/usr/bin/nvim
export VISUAL=/usr/bin/nano
export PAGER=/usr/bin/less

export ZLE_RPROMPT_INDENT=0               # don't leave an empty space after right prompt
export ZLE_REMOVE_SUFFIX_CHARS=''         # don't eat space when typing '|' after a tab completion
export READNULLCMD="${PAGER}"             # use the default pager instead of `more`
export WORDCHARS="${WORDCHARS//\/[&.;]}"  # don't consider certain characters part of the word

# --- Configure terminal pager ---
# This affects every invocation of `less`.
#   -i   case-insensitive search unless search string contains uppercase letters
#   -R   color
#   -F   exit if there is less than one page of content
#   -X   keep content on screen after exit
#   -M   show more info at the bottom prompt line
#   -x4  tabs are 4 instead of 8
export LESS="-iRFXMx4"

# --- Set man pages colors ---
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

export LS_ARGS="${LS_ARGS:---color=auto --group-directories-first --time-style=long-iso -h}"
export SDK_HOME="${SDK_HOME:-/usr/local}"
export ZSH_DEBUG_INIT="${ZSH_DEBUG_INIT:-0}"
