# File 40-devel.zsh; initialize path and environment variable for development tools
#
# Linux users might want to check the permission of their '/usr/local' path and chown
# it as needed, or if you're not so confident in doing this then set the DEV_HOME
# to set the directory where you would like to store your devtools (libs, sdks, etc).
#
# Another option is to set the value of DEV_USER_HOME_ACTIVE to 'true' which will use
# $HOME/.local as the prefix for your development tools.

export DEV_HOME="${DEV_HOME:-/usr/local}"
export DEV_USER_HOME="${DEV_USER_HOME:-${HOME}/.local}"
export DEV_USER_HOME_ACTIVE="${DEV_USER_HOME_ACTIVE:-false}"

fn.dev-prefix() {
  local prefix=''

  if [[ "${DEV_USER_HOME_ACTIVE}" == 'true' ]]; then
    prefix="${DEV_USER_HOME}"
  else
    prefix="${DEV_HOME}"
  fi

  # Resolve the directory path
  if (( ${+commands[realpath]} )); then
    echo $(realpath -m "${prefix}/${1}")
  else
    # Workaround for macOS without gnu coreutils from homebrew
    echo $(python "${ZDOTDIR}/utils/realpath.py" "${prefix}/${1}")
  fi
}

# Initialize nodejs prefix path
fn.init-node() {
  if (( ${+commands[node]} )); then
    alias nls='npm ls --depth=0'
    export NPM_CONFIG_PREFIX="$(fn.dev-prefix)"
  fi
}

# Initialize ruby gem location
fn.init-ruby() {
  if (( ${+commands[ruby]} )); then
    # Replace minor rev with zero; this is super slow
    # local full_ver="$(ruby -e 'print RUBY_VERSION')"
    # local ruby_ver="${full_ver%?}0"

    # do this for now until we can speed up ruby version detection
    local gem_path='ruby/gems/2.6.0'

    export GEM_HOME="$(fn.dev-prefix lib/${gem_path})"
    export GEM_SPEC_CACHE="${GEM_HOME}/specifications"
    export GEM_PATH="${GEM_HOME}"

    if $(fn.is-linux); then
      export GEM_PATH="${GEM_HOME}:/usr/lib/${gem_path}"
    fi

    if [[ ! -d "${GEM_HOME}" ]]; then
      eval "mkdir -p ${GEM_HOME}/{specifications,bin}"
    fi

    fn.pathmunge "${GEM_HOME}/bin"
  fi
}

# Initialize perl lib directory
fn.init-perl() {
  if (( ${+commands[perl]} )); then
    local base="$(fn.dev-prefix lib/perl5)"

    if $(fn.is-readable "${base}"); then
      export PATH="${base}/bin${PATH:+:${PATH}}"
      export PERL5LIB="${base}${PERL5LIB:+:${PERL5LIB}}"
      export PERL_LOCAL_LIB_ROOT="${base}${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
      export PERL_MB_OPT="--install_base \"${base}\""
      export PERL_MM_OPT="INSTALL_BASE=${base}"
    fi
  fi
}

# Initialize python env and aliases
fn.init-python() {
  if (( ${+commands[python]} )); then
    alias py='python'
    alias pyinst='pip install'
    alias pyupgd='pip install --upgrade'
    alias pytool='pip install --upgrade pip inittools wheel'
    alias pyhttp='python -m http.server' # starts a python lightweight http server
    alias pyjson='python -m json.tool'   # pipe to this alias to format json with python

    export PYTHONUSERBASE="$(fn.dev-prefix)"

    jsoncat() {
      if $(fn.is-not-empty "${1}"); then
        cat "${1}" | pyjson
      else
        echo 'File is empty.'
      fi
    }
  fi

  # Used by chromium build script
  if (( ${+commands[python2]} )); then
    export PNACLPYTHON="$(command -v python2)"
  fi
}

# Initialize google cloud sdk toolkit
fn.init-gcloud() {
  export GCLOUD_SDK_DIR="$(fn.dev-prefix lib/google-cloud-sdk)"

  if $(fn.is-readable "${GCLOUD_SDK_DIR}"); then
    local shell=$(basename "${SHELL}")
    source "${GCLOUD_SDK_DIR}/path.${shell}.inc"
    source "${GCLOUD_SDK_DIR}/completion.${shell}.inc"

    alias gcs="gcloud"
    alias gcb="gcs beta"
    alias gsp="cloud_sql_proxy"
  fi
}

# Wrapper function for google cloud components
if (( ${+commands[gcloud]} )); then
  gcm() {
    typeset -A args

    args[i]='install'
    args[u]='update'
    args[ls]='list'
    args[rm]='remove'
    args[rs]='restore'
    args[re]='reinstall'
    args[repo]='repositories'
    args[help]='--help'

    # Iterate key-val for debugging
    #
    # for key val in ${(kv)args}; do
    #   echo "$key -> $val"
    # done

    local arg="${args[$1]}"
    local cmd='gcloud components'

    if [[ -z "${arg}" ]]; then
      eval "${cmd} ${@}"
    else
      eval "${cmd} ${arg} ${@:2}"
    fi
  }
fi

# Initialize sdk manager
fn.init-sdkman() {
  export SDKMAN_DIR="$(fn.dev-prefix lib/sdkman)"
  local init_script="${SDKMAN_DIR}/bin/sdkman-init.sh"

  case "${1}" in
  'install')
    curl -s "https://get.sdkman.io" | zsh
    ;;
  *)
    if $(fn.is-readable "${init_script}"); then
      export GROOVY_TURN_OFF_JAVA_WARNINGS='true'
      export GRADLE_USER_HOME="${DEV_USER_HOME}/share/gradle"

      mkdir -p "${SDKMAN_DIR}/ext"
      source "${init_script}"
    fi
    ;;
  esac
}

# Initialize all devtools
fn.init-dev() {
  fn.init-ruby
  fn.init-node
  fn.init-perl
  fn.init-python
  fn.init-gcloud
  fn.init-sdkman
}

# Init everything
fn.init-dev

# Add .local/bin to PATH
fn.pathmunge "${DEV_USER_HOME}/bin"
