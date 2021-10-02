# ===========================================================================================
# File 04_devel.zsh; initialize path and environment variable for development tools
#
# Linux users might want to check the permission of their '/usr/local' path and chown
# it as needed, or if you're not so confident in doing this then set the DEV_HOME
# to set the directory where you would like to store your devtools (libs, sdks, etc).
#
# Another option is to set the value of DEV_USER_HOME_ACTIVE to 'true' which will use
# $HOME/.local as the prefix for your development tools.
# ===========================================================================================

export DEV_HOME="${DEV_HOME:-/usr/local}"
export DEV_USER_HOME="${DEV_USER_HOME:-${HOME}/.local}"
export DEV_USER_HOME_ACTIVE="${DEV_USER_HOME_ACTIVE:-false}"

# Docker command wrapper
if (( ${+commands[docker]} )); then
  # Docker pretty ps
  alias dps='docker-pretty-ps'

  docker() {
    typeset -A args

    args[com]='compose'
    args[pps]='pretty'
    args[img]='image'
    args[net]='network'
    args[ver]='version'
    args[vol]='volume'

    local arg="${args[$1]}"
    local cmd='/usr/bin/docker'

    if [[ -z "${arg}" ]]; then
      "${cmd} ${@}"
    elif [[ "${arg}" == 'compose' ]]; then
      "docker-compose ${@:2}"
    elif [[ "${arg}" == 'pretty' ]]; then
      "docker-pretty-ps ${@:2}"
    else
      "${cmd} ${arg} ${@:2}"  
    fi
  }
fi

# Google cloud components wrapper
if (( ${+commands[gcloud]} )); then
  gcp() {
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

devtools_prefix() {
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

# Initialize google cloud sdk toolkit
devtools_gcp() {
  export GCLOUD_SDK_DIR="$(devtools_prefix lib/google-cloud-sdk)"

  if [[ -r "${GCLOUD_SDK_DIR}" ]]; then
    local shell=$(basename "${SHELL}")
    source "${GCLOUD_SDK_DIR}/path.${shell}.inc"
    source "${GCLOUD_SDK_DIR}/completion.${shell}.inc"

    alias gcs="gcloud"
    alias gcb="gcs beta"
    alias gsp="cloud_sql_proxy"
  fi
}

# Initialize sdk manager
devtools_jvm() {
  export SDKMAN_DIR="$(devtools_prefix sdk)"
  local init_script="${SDKMAN_DIR}/bin/sdkman-init.sh"

  case "${1}" in
  'install')
    curl -s "https://get.sdkman.io" | zsh
    ;;
  *)
    if [[ -r "${init_script}" ]]; then
      export GROOVY_TURN_OFF_JAVA_WARNINGS='true'
      export GRADLE_USER_HOME="${DEV_USER_HOME}/lib/gradle"

      mkdir -p "${SDKMAN_DIR}/ext"
      source "${init_script}"
    fi
    ;;
  esac
}

# Initialize nodejs prefix path
devtools_node() {
  if (( ${+commands[node]} )); then
    alias nls='npm ls --depth=0'
    export NPM_CONFIG_PREFIX="$(devtools_prefix)"
  fi
}

# Initialize ruby gem location
devtools_ruby() {
  if (( ${+commands[ruby]} )); then
    local full_ver="$(ruby -e 'puts RUBY_VERSION')"
    local gem_path="ruby/gems/${full_ver%?}0" # transform 2.7.1 to 2.7.0

    export GEM_HOME="$(devtools_prefix lib/${gem_path})"
    export GEM_SPEC_CACHE="${GEM_HOME}/specifications"
    export GEM_PATH="${GEM_HOME}"

    if $(sys is-linux); then
      export GEM_PATH="${GEM_HOME}:/usr/lib/${gem_path}"
    fi

    if [[ ! -d "${GEM_HOME}" ]]; then
      eval "mkdir -p ${GEM_HOME}/{specifications,bin}"
    fi

    path_munge "${GEM_HOME}/bin"
  fi
}

# Initialize python env and aliases
devtools_python() {
  if (( ${+commands[python]} )); then
    alias py='python'
    alias pyinst='pip install'
    alias pyupgd='pip install --upgrade'
    alias pytool='pip install --upgrade pip inittools wheel'
    alias pyhttp='python -m http.server' # starts a python lightweight http server
    alias pyjson='python -m json.tool'   # pipe to this alias to format json with python

    export PYTHONUSERBASE="$(devtools_prefix)"

    jsoncat() {
      if [[ -s "$1" ]]; then
        cat "$1" | pyjson
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

# Initialize all devtools
devtools_init() {
  devtools_gcp
  devtools_jvm
  devtools_node
  devtools_ruby
  devtools_python
}

# Init everything
devtools_init

# Add .local/bin to PATH
path_munge "${DEV_USER_HOME}/bin"
