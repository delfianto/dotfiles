# File 40-devel.sh; initialize path and environment variable for development tools
#
# Linux users might want to check the permission of their '/usr/local' path and chown
# it as needed, or if you're not so confident in doing this then set the DEV_PREFIX
# to set the directory where you would like to store your devtools (libs, sdks, etc).

export LOCAL_HOME="${HOME}/.local"
export DEV_PREFIX="${DEV_PREFIX-/usr/local}"
export DEV_USE_HOME='true'

zsh_dev_prefix() {
  local prefix=''

  if [[ "${DEV_USE_HOME}" == 'true' ]]; then
    prefix="${LOCAL_HOME}"
  else
    prefix="${DEV_PREFIX}"
  fi

  # Use readlink instead of realpath because the path may not be exists
  # when we construct them (e.g. perl, sdkman, gradle cache dir, etc)
  echo $(readlink -m "${prefix}/${1}")
}

# Initialize nodejs prefix path
zsh_init_node() {
  if $(zsh_has_cmd node); then
    alias nls='npm ls --depth=0'
    export NPM_CONFIG_PREFIX="$(zsh_dev_prefix)"
  fi
}

# Initialize ruby gem location
zsh_init_ruby() {
  if $(zsh_has_cmd ruby); then
    # Replace minor rev with zero
    local full_ver="$(ruby -e 'print RUBY_VERSION')"
    local ruby_ver="${full_ver%?}0"

    export GEM_HOME="$(zsh_dev_prefix ruby/${ruby_ver})"
    export GEM_SPEC_CACHE="${GEM_HOME}/specifications"
    export GEM_PATH="${GEM_HOME}:/usr/lib/ruby/gem/${ruby_ver}"
  fi
}

# Initialize perl lib directory
zsh_init_perl5() {
  if $(zsh_has_cmd perl); then
    local base="$(zsh_dev_prefix lib/perl5)"

    if $(zsh_is_readable "${base}"); then
      export PATH="${base}/bin${PATH:+:${PATH}}"
      export PERL5LIB="${base}${PERL5LIB:+:${PERL5LIB}}"
      export PERL_LOCAL_LIB_ROOT="${base}${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
      export PERL_MB_OPT="--install_base \"${base}\""
      export PERL_MM_OPT="INSTALL_BASE=${base}"
    fi
  fi
}

# Initialize python env and aliases
zsh_init_python() {
  if $(zsh_has_cmd python); then
    alias py='python'
    alias pyinst='pip install'
    alias pyupgd='pip install --upgrade'
    alias pytool='pip install --upgrade pip setuptools wheel'
    alias pyhttp='python -m http.server' # starts a python lightweight http server
    alias pyjson='python -m json.tool'   # pipe to this alias to format json with python

    export PYTHONUSERBASE="$(zsh_dev_prefix)"

    jsoncat() {
      if $(zsh_is_not_empty "${1}"); then
        cat "${1}" | pyjson
      else
        echo 'File is empty.'
      fi
    }
  fi

  # Used by chromium build script
  if $(zsh_has_cmd python2); then
    export PNACLPYTHON="$(command -v python2)"
  fi
}

# Initialize google cloud sdk toolkit
zsh_init_gcloud() {
  export GCLOUD_SDK_DIR="$(zsh_dev_prefix lib/google-cloud-sdk)"

  if $(zsh_is_readable "${GCLOUD_SDK_DIR}"); then
    local shell=$(basename "${0}")
    zsh_source "${GCLOUD_SDK_DIR}/path.${shell}.inc"
    zsh_source "${GCLOUD_SDK_DIR}/completion.${shell}.inc"

    alias gcs="gcloud"
    alias gcb="gcs beta"
    alias gcm="gcs components"
    alias gsp="cloud_sql_proxy"
  fi
}

# Initialize sdk manager
zsh_init_sdkman() {
  export SDKMAN_DIR="$(zsh_dev_prefix lib/sdkman)"
  local init_script="${sdk_dir}/bin/sdkman-init.sh"

  case "${1}" in
    'install')
      curl -s "https://get.sdkman.io" | zsh
    ;;
    *)
      if $(zsh_is_file "${init_script}"); then
        export GROOVY_TURN_OFF_JAVA_WARNINGS='true'
        export GRADLE_USER_HOME="${LOCAL_HOME}/share/gradle"

        mkdir -p "${SDKMAN_DIR}/ext"
        source "${init_script}"
      fi
    ;;
  esac
}
