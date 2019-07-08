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

  if (( ! $+commands[brew] )); then
    echo "WARNING: Homebrew is not installed"
    echo "WARNING: Run 'fn.brew install' first"
    return 1
  fi

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

  # Zplug for macOS
  fn.source "${prefix}/opt/zplug/init.zsh"

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

# Homebrew setup (useful for new machine)
pkg() {
  # Homebrew was designed to work with the default macOS ruby
  local bin='/usr/bin/ruby'
  local git='https://raw.githubusercontent.com/Homebrew/install/master'

  case "${1}" in
  'setup')
    "${bin}" $(curl -fsSL "${git}/install")
    ;;
  'purge')
    "${bin}" $(curl -fsSL "${git}/uninstall")
    ;;
  'init')
    fn.init-brew
    ;;
  'i')
    brew install "${@:2}"
    ;;
  't')
    brew update "${@:2}"
    ;;
  'u')
    brew upgrade "${@:2}"
    ;;
  'rm')
    brew uninstall "${@:2}"
    ;;
   *)
    brew "$@"
    ;;
  esac
}

pkg 'init'
