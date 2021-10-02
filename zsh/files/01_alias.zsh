# =====================================================
# File 01_alias.zsh; common shell alias initialization
# =====================================================

# Replace 'cat' with 'bat'
if (( ${+commands[bat]} )); then
  alias cat='bat'
fi

# Shell command alias
alias cls="clear && printf '\e[3J'"
alias which='command -v'
alias shdir="cd ${ZDOTDIR}"

# Disk usage in human readable format
alias du='du -h'
alias ds='du -s'
alias df='df -h'

# Make some of the file manipulation programs verbose
alias mv='mv -v'
alias cp='cp -v'

# Use safe-rm if present
if (( $+commands[safe-rm] )); then
  alias rm='safe-rm'
fi

# Colorize the grep command output;
# Good for your eyes when reading long log files
alias grep='grep -i --color=auto'
alias egrep='egrep -i --color=auto'
alias fgrep='fgrep -i --color=auto'

# Allow aliases to be sudo’ed
alias sudo='sudo '

# Reloads the current shell
alias reload="exec ${SHELL} -l"
