# File zshrc-darwin; macOS specific zsh setup
#
# Setup homebrew and development evironment specific to macOS

# Runtime env check, bail out if os does not match
fn.os-match 'macos'
if [[ "$?" != 0 ]]; then
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

fn.brew-setup() {
  local prefix="${1:-'/usr/local'}"
  export HOMEBREW_PREFIX="${prefix}"

  if (( $+commands[brew] )); then
  else
    echo "WARNING: Homebrew is not installed" && return 1
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

  # gnu tools and manpage from homebrew
  for gnu in $(echo -e 'coreutils findutils gnu-sed gnu-tar'); do
    local path="${prefix}/opt/${gnu}/libexec"

    if $(fn.is-readable "${path}"); then
      local gnubin="${path}/gnubin"
      local gnuman="${path}/gnuman"

      $(fn.is-readable "${gnubin}") && export PATH="${gnubin}:${PATH}"
      $(fn.is-readable "${gnuman}") && export MANPATH="${gnuman}:${MANPATH}"
    fi
  done

  # Ruby from homebrew
  $(fn.is-readable "${prefix}/opt/ruby/bin") &&
    export PATH="${prefix}/opt/ruby/bin:${PATH}" &&
    fn.setup-ruby

  # Apache Tomcat from homebrew
  $(fn.is-readable "${prefix}/opt/tomcat") &&
    export CATALINA_HOME="${prefix}/opt/tomcat/libexec"

  # Homebrew cask options
  fn.source "${ZDOTDIR}/private/homebrew.zsh"
  export HOMEBREW_CASK_OPTS='--appdir=/Applications'

  # Use same package management alias with linux
  alias pkg='brew'
}

# Homebrew setup (useful for new machine)
fn.brew() {
  local rb='/usr/bin/ruby -e'

  case "${1}" in
  'install')
    "${rb} $(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    ;;
  'uninstall')
    "${rb} $(curl -fsSL https://raw.githubusercontent.com/homebrew/install/master/uninstall)"
    ;;
  'setup')
    $(fn.brew-setup)
    ;;
  '')
    echo "${0} [install | uninstall | setup]"
    ;;
  esac
}

fn.brew 'setup'
