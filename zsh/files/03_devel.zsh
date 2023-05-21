# ===========================================================================================
# File 04_devel.zsh; initialize path and environment variable for development tools
#
# Linux users might want to check the permission of their '/usr/local' path and chown
# it as needed, or if you're not so confident in doing this then set the DEV_HOME
# to set the directory where you would like to store your devtools (libs, sdks, etc).
#
# Another good option is to set DEV_HOME to $HOME/.local as the current user
# is guaranteed to have read/write access to this directory.
# ===========================================================================================

export DEV_HOME="${DEV_HOME:-/usr/local}"

if (( ! ${+commands[realpath]} )); then
  echo 'Warning: Realpath command does not exist in $PATH'
  echo 'Warning: DevTools initialization skipped'
  return 1
fi

get_prefix() {
  local prefix=$(realpath -q "${DEV_HOME}/${1}")

  if [[ -z "${prefix}" ]]; then
    echo "${DEV_HOME}/${1}"
  else
    echo "${prefix}"
  fi
}

# Docker command wrapper
docker() {
  if (( ! ${+commands[docker]} )); then
    echo 'Docker is not installed'
    return 1
  fi

  # Docker pretty ps
  alias dps='docker-pretty-ps'

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
    "${cmd}" "${@}"
  elif [[ "${arg}" == 'compose' ]]; then
    docker-compose "${@:2}"
  elif [[ "${arg}" == 'pretty' ]]; then
    docker-pretty-ps
  else
    "${cmd}" "${arg}" "${@:2}"
  fi
}

# Google cloud command wrapper
gcp() {
  if (( ! ${+commands[gcloud]} )); then
    echo 'Cloud Command Line Tools is not installed'
    return 1
  fi

  typeset -A args

  args[i]='install'
  args[up]='update'
  args[ls]='list'
  args[rm]='remove'
  args[rs]='restore'
  args[re]='reinstall'
  args[repo]='repositories'
  args[help]='--help'

  # Iterate key-val for debugging
  # for key val in ${(kv)args}; do
  #   echo "$key -> $val"
  # done

  local arg="${args[$1]}"
  local cmd='gcloud components'

  if [[ -z "${arg}" ]]; then
    "${cmd}" "${@}"
  else
    "${cmd}" "${arg}" "${@:2}"
  fi
}

# Initialize google cloud sdk toolkit
init_gcloud() {
  if (( ! ${+commands[gcloud]} )); then
    return 1
  fi

  export GCLOUD_SDK_DIR="$(get_prefix lib/google-cloud-sdk)"

  if [[ -r "${GCLOUD_SDK_DIR}" ]]; then
    local shell=$(basename "${SHELL}")
    source "${GCLOUD_SDK_DIR}/path.${shell}.inc"
    source "${GCLOUD_SDK_DIR}/completion.${shell}.inc"

    alias gcs="gcloud"
    alias gcb="gcs beta"
    alias gsp="cloud_sql_proxy"
  fi
}

# Initialize nodejs prefix path
init_nodejs() {
  if (( ${+commands[node]} )); then
    alias nls='npm ls --depth=0'
    export NPM_CONFIG_PREFIX="$(get_prefix)"
  fi
}

# Initialize python env and aliases
init_python() {
  if (( ! ${+commands[python3]} )); then
    return 1
  fi

  alias py='python3'
  alias pyinst='pip3 install'
  alias pyupgd='pip3 install --upgrade'
  alias pytool='pip3 install --upgrade pip inittools wheel'
  alias pyhttp='python3 -m http.server' # starts a python lightweight http server
  alias pyjson='python3 -m json.tool'   # pipe to this alias to format json with python

  export PYTHONUSERBASE="$(get_prefix)"

  jsoncat() {
    if [[ -s "$1" ]]; then
      cat "$1" | pyjson
    else
      echo 'File is empty.'
    fi
  }
}

# Initialize ruby gem location
init_ruby() {
  if (( ! ${+commands[ruby]} )); then
    return 1
  fi

  local full_ver="$(ruby -e 'puts RUBY_VERSION')"
  local gem_path="ruby/gems/${full_ver%?}0" # transform 2.7.1 to 2.7.0

  export GEM_HOME="$(get_prefix lib/${gem_path})"
  export GEM_SPEC_CACHE="${GEM_HOME}/specifications"
  export GEM_PATH="${GEM_HOME}"

  if [[ "${OS_NAME}" == 'linux' ]]; then
    export GEM_PATH="${GEM_HOME}:/usr/lib/${gem_path}"
  fi

  if [[ ! -d "${GEM_HOME}" ]]; then
    eval "mkdir -p ${GEM_HOME}/{specifications,bin}" &> /dev/null
  fi

  path_munge "${GEM_HOME}/bin"
}

# Initialize sdk manager
init_sdkman() {
  export SDKMAN_DIR="$(get_prefix sdkman)"
  local sdkman_init="${SDKMAN_DIR}/bin/sdkman-init.sh"

  if [[ -r "${sdkman_init}" ]]; then
    export GROOVY_TURN_OFF_JAVA_WARNINGS='true'
    export GRADLE_USER_HOME="${DEV_USER_HOME}/lib/gradle"

    eval "mkdir -p ${SDKMAN_DIR}/ext" &> /dev/null
    source "${sdkman_init}"
  else
    unset SDKMAN_DIR
  fi
}

# Init everything
init_gcloud
unfunction init_gcloud

init_nodejs
unfunction init_nodejs

init_python
unfunction init_python

init_ruby
unfunction init_ruby

init_sdkman
unfunction init_sdkman

# Final Cleanup
unfunction get_prefix

# Ensure ~/.local/bin and $DEV_HOME/bin is added to PATH
path_munge "${HOME}/.local/bin"
path_munge "${DEV_USER_HOME}/bin"
