# =====================================================
# File 02_shell_alias.zsh; common alias initialization
# =====================================================

_ls_args='--color=auto --group-directories-first -hFX'

if zsh::is_linux; then
  alias ls="ls ${_ls_args}"
  alias ll="ls ${_ls_args} -l"
  alias la="ls ${_ls_args} -a"
else
  if (( ${+commands[gls]} )); then
    # macOS with gnu coreutils from homebrew
    alias ls="gls ${_ls_args}"
    alias ll="gls ${_ls_args} -l"
    alias la="gls ${_ls_args} -a"
  else
    # other Unix, most probably BSD or Solaris
    alias ll="ls -l"
    alias la="ls -a"
  fi
fi

unset _ls_args

# Replace 'cat' with 'bat'
if (( ${+commands[bat]} )); then
  alias cat='bat'
fi

# Alias for some zsh::function
alias lspath='zsh::ls_path'
alias lsenv='zsh::ls_env'
alias lsfun='zsh::ls_fun'

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
