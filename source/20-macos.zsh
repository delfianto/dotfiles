# File zshrc-darwin; macOS specific zsh setup
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

fn.init-brew() {
  local prefix="${1:-/usr/local}"
  export HOMEBREW_PREFIX="${prefix}"
  export HOMEBREW_GNU_UTILS="${HOMEBREW_GNU_UTILS:-false}"

  if (( ! $+commands[brew] )); then
    echo "WARNING: Homebrew is not installed"
    echo "WARNING: Run 'fn.brew install' first"
    return 1
  fi

  # Zplug for macOS
  fn.source "${prefix}/opt/zplug/init.zsh"

  if [[ "${HOMEBREW_GNU_UTILS}" == 'true' ]]; then
    # gnu tools and manpage from homebrew
    for gnu in $(echo -e 'coreutils findutils gnu-sed gnu-tar'); do
      local gnu_lib="${prefix}/opt/${gnu}/libexec"

      if [[ -r "${gnu_lib}" ]]; then
        local gnubin="${gnu_lib}/gnubin"
        local gnuman="${gnu_lib}/gnuman"

        $(fn.is-readable "${gnubin}") && export PATH="${gnubin}:${PATH}"
        $(fn.is-readable "${gnuman}") && export MANPATH="${gnuman}:${MANPATH}"
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

# Homebrew command wrapper
pkg() {
  typeset -A args

  local brew='brew'
  local curl='curl -fsSL'
  local ruby='/usr/bin/ruby -e' # Use ruby bin that shipped with macOS
  local repo='https://raw.githubusercontent.com/Homebrew/install/master'

  args[setup]="${bin} $(${curl} ${git}/install)"
  args[purge]="${bin} $(${curl} ${git}/uninstall)"

  args[i]="${brew} install"
  args[p]="${brew} update"
  args[u]="${brew} upgrade"
  args[rm]="${brew} uninstall"
  args[ls]="${brew} list"

  local cmd="${args[$1]}"

  if [[ -z "${cmd}" ]]; then
    eval "${cmd} ${@:2}"
  else
    eval "${brew} $@"
  fi
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

fn.init-brew
