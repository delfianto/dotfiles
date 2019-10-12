# File 20-macos.zsh; macOS specific zsh setup
#
# Setup homebrew and environment variables specific to macOS

if [[ "${OS_NAME}" != 'macos' ]]; then
  return 1
fi

# Add spacer to dock
fn.dock-spacer() {
  defaults write com.apple.dock persistent-apps -array-add '{"tile-type"="spacer-tile";}'
  killall Dock
}

# Remove all .DS_Store from current directory
fn.clean-store() {
  find . -name ".DS_Store" -delete
}

fn.brew-init() {
  local prefix="${1:-/usr/local}"
  export HOMEBREW_PREFIX="${prefix}"
  export HOMEBREW_GNU_UTILS="${HOMEBREW_GNU_UTILS:-true}"

  if (( ! $+commands[brew] )); then
    echo "WARNING: Homebrew is not installed"
    echo "WARNING: Run 'fn.brew install' first"
    return 1
  fi

  # Zplug for macOS
  fn.source "${prefix}/opt/zplug/init.zsh"

  # ZSH completion from homebrew
  fpath=(/usr/local/share/zsh-completions $fpath)

  if [[ "${HOMEBREW_GNU_UTILS}" == 'true' ]]; then
    # GNU utilities and manpage from homebrew
    for gnu in $(echo -e 'coreutils findutils gnu-sed gnu-tar gnu-indent gnu-which'); do
      local gnu_lib="${prefix}/opt/${gnu}/libexec"

      if [[ -r "${gnu_lib}" ]]; then
        fn.pathmunge "${gnu_lib}/gnubin"
      fi
    done
  fi

  # Ruby from homebrew
  local ruby_bin="${prefix}/opt/ruby/bin"
  [[ -r "${ruby_bin}" ]] && export PATH="${ruby_bin}:${PATH}"

  # Apache Tomcat from homebrew
  local catalina_home="${prefix}/opt/tomcat"
  [[ -r "${catalina_home}" ]] && export CATALINA_HOME="${catalina_home}"

  # Homebrew cask options
  local homebrew_cask="${ZDOTDIR}/private/homebrew.zsh"
  [[ -r "${homebrew_cask}" ]] && source "${homebrew_cask}"
  export HOMEBREW_CASK_OPTS='--appdir=/Applications'
}

fn.brew-install() {
  if (( ${+commands[brew]} )); then
    echo 'Homebrew is already installed.'
    exit 1
  else
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi
}

fn.brew-uninstall() {
  if (( ${+commands[brew]} )); then
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
  else
    echo 'Homebrew is not installed.'
    exit 1
  fi
}

fn.brew() {
  typeset -A args
  args[init]="fn.brew-init"
  args[install]="fn.brew-install"
  args[uninstall]="fn.brew-uninstall"
  eval "${args[$1]}"
}

# Homebrew command wrapper
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
    echo "Usage: ${FUNCNAME[0]} [list | run | start | stop | restart | cleanup] [...]"
    echo "Running without any param will list all available services"
    ;;
  *)
    "${FUNCNAME[0]}" 'ls'
    ;;
  esac
}

fn.brew init
