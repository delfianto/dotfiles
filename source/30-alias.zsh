# File 20-alias.zsh; common alias initialization
#
# Functions and aliases used by all operating systems

# Lazy load function to add ls arguments
# ls() {
#   unset -f "$0"
#   export LS_ARGS="--color='auto'"

#   # Check which variant of ls that we use
#   case $(fn.ls-type) in
#   'gnu')
#     LS_ARGS="-hFX --group-directories-first"
#     ;;
#   'bsd')
#     LS_ARGS="-hFG"
#     ;;
#   *)
#     LS_ARGS=''
#     ;;
#   esac

#   alias ls="ls ${LS_ARGS}"
#   alias ll="ls ${LS_ARGS} -l"
#   alias la="ls ${LS_ARGS} -a"

#   ls ${@}${LS_ARGS}
# }

# Shell command alias
alias c="clear && printf '\e[3J'"
alias cls='c'
alias which='command -v'
alias zshdir="cd ${ZDOTDIR}"

# Disk usage in human readable format
alias du='du -h'
alias ds='du -s'
alias df='df -h'

# Make some of the file manipulation programs verbose
alias mv='mv -v'
alias cp='cp -v'

# Use safe-rm if present
if (( $+commands[safe-rm] )); then
  alias rf='safe-rm'
fi

# Colorize the grep command output;
# Good for your eyes when reading long log files
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Allow aliases to be sudo’ed
alias sudo='sudo '

# Reloads the current shell
alias reload="exec ${SHELL} -l"

# Aliases for parallel version of compression utility
# Some of this apperently broke package manager in Manjaro
#
# (( $+commands[pbzip2] )) && alias bzip2='pbzip2'
# (( $+commands[pigz] )) && alias gzip='pigz'
# (( $+commands[pixz] )) && alias xz='pixz'

# database command alias
if (( $+commands[mysql] )); then
  alias sql="mysql -u root -p"
fi

# add .local/bin to PATH
# export PATH="$(echo "${HOME}" | tr '[:upper:]' '[:lower:]')/.local/bin:${PATH}"
