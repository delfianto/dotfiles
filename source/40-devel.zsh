# File 40-devel.sh; initialize path and environment variable for development tools
#
# Linux users might want to check the permission of their '/usr/local' path and chown
# it as needed, or if you're not so confident in doing this then set the DEV_PREFIX
# to set the directory where you would like to store your devtools (libs, sdks, etc).

export LOCAL_HOME="${HOME}/.local"
export DEV_PREFIX="${DEV_PREFIX-/usr/local}"
export DEV_USE_HOME='true'

zsh_dev_prefix() {
  if [[ "${DEV_USE_HOME}" == 'true' ]] &&
    echo "${LOCAL_HOME}" || echo "${DEV_PREFIX}"
}

# Initialize Google Cloud SDK toolkit
zsh_init_gcloud() {

}

# Initialize NodeJS prefix path
zsh_init_node() {
  if $(zsh_has_cmd node); then
    export NPM_CONFIG_PREFIX="$(zsh_dev_prefix)"
  fi
}

# Initialize Ruby gem location
zsh_init_ruby() {
  if $(zsh_has_cmd ruby); then
    local full_ver="$(ruby -e 'print RUBY_VERSION')"

    # Replace minor rev with zero
    local ruby_ver="${full_ver%?}0"

    export GEM_HOME="$(zsh_dev_prefix)/ruby/${ruby_ver}"
    export GEM_SPEC_CACHE="${GEM_HOME}/specifications"
    export GEM_PATH="${GEM_HOME}:/usr/lib/ruby/gem/${ruby_ver}"
  fi
}

# Initialize Perl lib directory
zsh_init_perl5() {
  if $(zsh_has_cmd perl); then
    local base="$(zsh_dev_prefix)/lib/perl5"

    if $(zsh_is_readable "${base}"); then
      export PATH="${base}/bin${PATH:+:${PATH}}"
      export PERL5LIB="${base}${PERL5LIB:+:${PERL5LIB}}"
      export PERL_LOCAL_LIB_ROOT="${base}${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
      export PERL_MB_OPT="--install_base \"${base}\""
      export PERL_MM_OPT="INSTALL_BASE=${base}"
    fi
  fi
}

zsh_init_python() {
  if $(zsh_has_cmd python); then
    export PYTHONUSERBASE="$(zsh_dev_prefix)"
  fi

  # Used by chromium build script
  if $(zsh_has_cmd python2); then
    export PNACLPYTHON="$(command -v python2)"
  fi

  # Pretty print json file
  jsoncat() {
    if $(foo "${1}"); then
      cat "${1}" | pyjson
    fi
  }
}

# Initialize SDK Manager (JVM devtools)
zsh_init_sdkman() {
  local sdk_dir="${DEV_PREFIX}/lib/sdkman"
  local init_script="${sdk_dir}/bin/sdkman-init.sh"

  if $(zsh_is_file "${init_script}"); then
    export GROOVY_TURN_OFF_JAVA_WARNINGS='true'
    export GRADLE_USER_HOME="${LOCAL_HOME}/share/gradle"

    mkdir -p "${SDKMAN_DIR}/ext"
    source "${init_script}"
  fi
}
