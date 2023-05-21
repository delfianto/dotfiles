# ==================================================================
# File 03_macos.zsh; macos specific alias and environment variables
# ==================================================================

# Bail out if not sourced from macos
if [[ "${OS_NAME}" != 'macos' ]]; then
  return 1
fi

# Initialize homebrew stuff
if (( ${+commands[brew]} )); then
  export LC_ALL='en_US.UTF-8'
  export HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/usr/local}"
  export HOMEBREW_GNU_UTILS="${HOMEBREW_GNU_UTILS:-true}"

  # ZSH completion
  fpath=('/usr/local/share/zsh-completions' "${fpath[@]}" )

  if [[ "${HOMEBREW_GNU_UTILS}" == 'true' ]]; then
    # GNU utilities and manpage
    for gnu in $(echo -e 'coreutils findutils gnu-indent gnu-which gnu-sed gnu-tar'); do
      gnu_lib="${HOMEBREW_PREFIX}/opt/${gnu}/libexec"

      if [[ -r "${gnu_lib}" ]]; then
        path_munge "${gnu_lib}/gnubin"
      fi

      unset gnu_lib
    done
  fi

  # Homebrew local/sbin
  path_munge "${HOMEBREW_PREFIX}/sbin"

  # Ruby
  path_munge "${HOMEBREW_PREFIX}/opt/ruby/bin"

  # Python
  path_munge "${HOMEBREW_PREFIX}/opt/python/libexec/bin"

  # Apache Tomcat
  [[ -r "${HOMEBREW_PREFIX}/opt/tomcat" ]] && 
    export CATALINA_HOME="${HOMEBREW_PREFIX}/opt/tomcat"

  # Cask options
  zsh-in "${ZDOTDIR}/private/homebrew.zsh"
  export HOMEBREW_CASK_OPTS='--appdir=/Applications'
fi

# ls enhancement
if (( ${+commands[gls]} )); then
  # if gnu coreutils is installed
  alias ls="gls ${LS_ARGS}"
  alias ll="gls ${LS_ARGS} -l"
  alias la="gls ${LS_ARGS} -a"
else
  alias ll="ls -l"
  alias la="ls -a"
fi

beer() {
  local src='https://raw.githubusercontent.com/Homebrew/install/HEAD'
  
  case "${1}" in
    'setup')
      if (( ${+commands[brew]} )); then
        echo 'Homebrew is already installed'
        return 1
      fi

      /bin/bash -c "$(curl -fsSL ${src}/install.sh)"
      ;;
    'purge')
      /bin/bash -c "$(curl -fsSL ${src}/uninstall.sh)"
      ;;
    'chown')
      # https://stackoverflow.com/questions/16432071/how-to-fix-homebrew-permissions/46844441#46844441
      sudo chown -Rv $(whoami) $(brew --prefix)/*
      ;;
    *)
      echo "Usage: ${0} [ setup | purge ]"
      ;;
  esac
}

dock_spacer() {
  defaults write com.apple.dock persistent-apps -array-add '{"tile-type"="spacer-tile";}'
  killall Dock
}

host() {
  case "$1" in
  'set')
    if [[ ! -z "$2" ]]; then
      sudo scutil --set LocalHostName "$2"
      sudo scutil --set HostName "$2"
      dscacheutil -flushcache
    else
      echo 'Specify a new hostname to be set'
    fi
    ;;
  'help')
    echo "Usage: ${FUNCNAME[0]} [ set | help ]"
    echo "Running without any argument will invoke /bin/hostname"
    ;;
  *)
    hostname "${@:1}"
    ;;
  esac
}

pkg() {
  if (( !${+commands[brew]} )); then
    echo 'Homebrew is not installed.'
    return 1
  fi

  case "${1}" in
    'info')
      brew info "${@:2}"
      ;;
    'search')
      brew search "${@:2}"
      ;;
    'l' | 'ls' | 'list')
      brew list "${@:2}"
      ;;
    'i' | 'in' | 'install')
      brew install "${@:2}"
      ;;
    'r' | 'rm' | 'remove')
      brew uninstall "${@:2}"
      ;;
    'u' | 'up' | 'upgrade')
      brew upgrade "${@:2}"
      ;;
    's' | 'sy' | 'update')
      brew update
      ;;
    'c' | 'cfg' | 'config')
      brew config
      ;;
    'd' | 'doc' | 'doctor')
      brew doctor
      ;;
    *)
      brew "${@:1}"
      ;;
  esac
}

svc() {
  case "$1" in
  'run' | 'start' | 'stop' | 'restart')
    [[ ! -z "$2" ]] && brew services "$1" "$2" || "${FUNCNAME[0]}" 'help'
    ;;
  'ls' | 'list' | 'cleanup')
    brew services "$1"
    ;;
  'help')
    echo "Usage: ${FUNCNAME[0]} [ list | run | start | stop | restart | cleanup ] [...]"
    echo "Running without any argument will list all available services"
    ;;
  *)
    "${FUNCNAME[0]}" 'ls'
    ;;
  esac
}
