# File 30-alias.zsh; common alias initialization
#
# Functions and aliases used by all operating systems

_ls_args='--color=auto --group-directories-first -hFX'

if (( ${+commands[gls]} )); then
  alias ls="gls ${_ls_args}"
  alias ll="gls ${_ls_args} -l"
  alias la="gls ${_ls_args} -a"
else
  alias ls="ls ${_ls_args}"
  alias ll="ls ${_ls_args} -l"
  alias la="ls ${_ls_args} -a"
fi

unset _ls_args

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
