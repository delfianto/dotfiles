# File 20-alias.zsh; common alias initialization
# Functions and aliases used by all operating systems

zsh_init_ls() {
  # check what kind of ls that we use
  local ls_type=$(zsh_ls_type)

  if [[ "${ls_type}" == 'gnu' ]]; then
    # gnu ls
    local ls_args='-hFX --group-directories-first'
  elif [[ "${ls_type}" == "bsd" ]]; then
    # bsd ls
    ls_args='-hFG'
  else
    # solaris ls
    ls_args=''
  fi

  # improved ls outout
  alias ls="ls ${ls_args}"
  alias ll="ls ${ls_args} -l"
  alias la="ls ${ls_args} -a"
}

# initialize ls alias based on os
zsh_init_ls

# shell command alias
alias c="clear && printf '\e[3J'"
alias cls='c'
alias which='command -v'

# disk usage in human readable format
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

# make some of the file manipulation programs verbose
alias mv='mv -v'
alias cp='cp -v'

# use safe-rm if present
if $(zsh_has_cmd 'safe-rm'); then
  alias rf='safe-rm'
fi

# colorize the grep command output for ease of use (good for log files)
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# enable aliases to be sudo’ed
alias sudo='sudo '

# reloads the current shell
alias reload='exec zsh -l'

# aliases for compression utility
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
