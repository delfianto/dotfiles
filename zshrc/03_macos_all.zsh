# ================================================
# File 03_macos_all.zsh; macOS specific zsh setup
# ================================================

if [[ "${OS_NAME}" != 'macos' ]]; then
  return 1
fi

zsh::macos::brew_init() {
  local prefix="${1:-/usr/local}"
  export LC_ALL=en_US.UTF-8
  export HOMEBREW_PREFIX="${prefix}"
  export HOMEBREW_GNU_UTILS="${HOMEBREW_GNU_UTILS:-true}"

  if (( ! $+commands[brew] )); then
    echo "WARNING: Homebrew is not installed"
    echo "WARNING: Run 'brew_env install' first"
    return 1
  fi

  # Zplug for macOS
  zsh::source "${prefix}/opt/zplug/init.zsh"

  # ZSH completion from homebrew
  fpath=(/usr/local/share/zsh-completions $fpath)

  if [[ "${HOMEBREW_GNU_UTILS}" == 'true' ]]; then
    # GNU utilities and manpage from homebrew
    for gnu in $(echo -e 'coreutils findutils gnu-indent gnu-which gnu-sed gnu-tar'); do
      local gnu_lib="${prefix}/opt/${gnu}/libexec"

      if [[ -r "${gnu_lib}" ]]; then
        zsh::path_munge "${gnu_lib}/gnubin"
      fi
    done
  fi

  # Homebrew local/sbin
  zsh::path_munge "${prefix}/sbin"

  # Ruby from homebrew
  zsh::path_munge "${prefix}/opt/ruby/bin"

  # Python from homebrew
  zsh::path_munge "${prefix}/opt/python/libexec/bin"

  # Apache Tomcat from homebrew
  local catalina_home="${prefix}/opt/tomcat"
  [[ -r "${catalina_home}" ]] && export CATALINA_HOME="${catalina_home}"

  # Homebrew cask options
  local homebrew_cask="${ZDOTDIR}/private/homebrew.zsh"
  [[ -r "${homebrew_cask}" ]] && source "${homebrew_cask}"
  export HOMEBREW_CASK_OPTS='--appdir=/Applications'
}

zsh::macos::brew_setup() {
  if (( ${+commands[brew]} )); then
    echo 'Homebrew is already installed.'
    exit 1
  else
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi
}

zsh::macos::brew_purge() {
  if (( ${+commands[brew]} )); then
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
  else
    echo 'Homebrew is not installed.'
    exit 1
  fi
}

zsh::macos::brew_env() {
  typeset -A args
  args[start]="zsh::macos::brew_init"
  args[setup]="zsh::macos::brew_setup"
  args[purge]="zsh::macos::brew_purge"
  eval "${args[$1]}"
}

pkg() {
  if (( !${+commands[brew]} )); then
    echo 'Homebrew is not installed.'
    exit 1
  fi

  local cmd='brew'

  case "$1" in
    'info')
      "${cmd}" info "${@:2}"
      ;;
    'search')
      "${cmd}" search "${@:2}"
      ;;
    'l' | 'ls' | 'list')
      "${cmd}" list "${@:2}"
      ;;
    'i' | 'in' | 'install')
      "${cmd}" install "${@:2}"
      ;;
    'r' | 'rm' | 'remove')
      "${cmd}" uninstall "${@:2}"
      ;;
    'u' | 'up' | 'upgrade')
      "${cmd}" upgrade "${@:2}"
      ;;
    's' | 'sy' | 'update')
      "${cmd}" update
      ;;
    'c' | 'cfg' | 'config')
      "${cmd}" config
      ;;
    'd' | 'doc' | 'doctor')
      "${cmd}" doctor
      ;;
    *)
      "${cmd}" "${@:1}"
      ;;
  esac
}

# Wrapper for hostname
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
    /bin/hostname "${@:1}"
    ;;
  esac
}

# Wrapper for homebrew service
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

# Add spacer to dock
dock_spacer() {
  defaults write com.apple.dock persistent-apps -array-add '{"tile-type"="spacer-tile";}'
  killall Dock
}

zsh::macos::brew_env start
