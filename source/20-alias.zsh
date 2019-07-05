# File 20-alias.zsh; common alias initialization
# Functions and aliases used by all operating systems

zsh_init_ls() {
  local ls_args='--color=auto'

  # Check which variant of ls that we use
  case $(zsh_ls_type) in
    'gnu')
      ls_args="${ls_args} -hFX --group-directories-first"
    ;;
    'bsd')
      ls_args='${ls_args} -hFG'
    ;;
    *)
      ls_args=''
    ;;
  esac

  alias ls="ls ${ls_args}"
  alias ll="ls ${ls_args} -l"
  alias la="ls ${ls_args} -a"
}

# Add ls args based on os
zsh_init_ls

# Shell command alias
alias c="clear && printf '\e[3J'"
alias cls='c'
alias which='command -v'

# Disk usage in human readable format
alias du='du -h'
alias ds='du -s'
alias df='df -h'

cdf() {
  df -h | grep -v ^none | (
    read header
    echo "$header"
    sort -n -k 1
  )
}

# Make some of the file manipulation programs verbose
alias mv='mv -v'
alias cp='cp -v'

# Use safe-rm if present
if $(zsh_has_cmd 'safe-rm'); then
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
alias reload='exec zsh -l'

# Aliases for parallel version of compression utility
# Some of this apperently broke package manager in Manjaro
#
# $(zsh_has_cmd 'pbzip2') && alias bzip2='pbzip2'
# $(zsh_has_cmd 'pigz') && alias gzip='pigz'
# $(zsh_has_cmd 'pixz') && alias xz='pixz'

# npm command alias
if $(zsh_has_cmd 'npm'); then
  alias nls='npm ls --depth=0'
fi

# database command alias
if $(zsh_has_cmd 'mysql'); then
  alias sql="mysql -u root -p"
fi

# python command aliases
if $(zsh_has_cmd 'python3'); then
  export PIP_CONFIG_FILE="${conf_dir}/pip.conf"

  alias py='python3'
  alias pyhttp='python3 -m http.server' # starts a python lightweight http server
  alias pyjson='python3 -m json.tool'   # pipe to this alias to format json with python

  alias pyinst='pip3 install'
  alias pyupgd='pip3 install --upgrade'
  alias pytool='pip3 install --upgrade pip setuptools wheel'

  jsoncat() {
    if $(file_not_empty "${1}"); then
      cat "${1}" | pyjson
    fi
  }
fi

# add .local/bin to PATH
# export PATH="$(echo "${HOME}" | tr '[:upper:]' '[:lower:]')/.local/bin:${PATH}"

# clean up duplicates entry in PATH
# export PATH=$(printf "%s" "${PATH}" | awk -v RS=':' '!a[$1]++ { if (NR > 1) printf RS; printf $1 }')
