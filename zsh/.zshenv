# File .zshenv; zsh environment config

# ZSH debug initialization
export ZSH_DEBUG_INIT="${ZSH_DEBUG_INIT:-0}"

# ZSH dotfile locations
export DOTDIR="${DOTDIR:-${HOME}/.config/dotfiles}"
export MYCONF="${MYCONF:-${HOME}/.config/myconf}"
export ZDOTDIR="${ZDOTDIR:-${HOME}/.config/zsh}"

# Ensure .local/bin is added to PATH
export PATH="$HOME/.local/bin:$PATH"

source_env() {
  local env_file="$ZDOTDIR/env.$1.zsh"; shift

  if [[ -r "$env_file" ]]; then
    source "$env_file"
  elif [[ -f "$env_file" ]]; then
    print "Error: $env_file is not readable" >&2
  else
    print "Warning: $env_file not found" >&2
  fi
}

# Source the appropriate .env file based on the OS
case "$OSTYPE" in
  linux-gnu*)
    source_env "linux"
    ;;
  darwin*)
    source_env "macos"
    ;;
  *)
    print "Warning: OS not detected as Linux or macOS (using OSTYPE), no .env file sourced." >&2
    ;;
esac

# Don't keep duplicates and ignore specific sets of command from history
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

# Configure terminal pager
# This affects every invocation of `less`.
#   -i   case-insensitive search unless search string contains uppercase letters
#   -R   color
#   -F   exit if there is less than one page of content
#   -X   keep content on screen after exit
#   -M   show more info at the bottom prompt line
#   -x4  tabs are 4 instead of 8
export LESS="-iRFXMx4"

# Set man pages colors
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

source_env "dev"
unset -f source_env
