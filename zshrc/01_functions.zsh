# ===============================================
# File 01_functions.zsh; common helper functions
# ===============================================

# Enable call of an existing function using sudo
# https://unix.stackexchange.com/questions/317687/command-not-found-when-sudoing-function-from-zshrc
zsh::sudo() {
  sudo zsh -c "$functions[$1]" "$@"
}

zsh::bench() {
  for i in $(seq 1 10); do
    time "${SHELL}" -i -c exit
  done
}

zsh::emoji() {
  if [[ "$?" == 0 ]]; then
    echo '🍄'
  else
    echo '💀'
  fi
}

zsh::get_ls() {
  if $(ls --color -d "${HOME}" >/dev/null 2>&1); then
    echo 'gnu'
  elif $(ls -G -d "${HOME}" >/dev/null 2>&1); then
    echo 'bsd'
  else
    echo 'solaris'
  fi
}

zsh::get_os() {
  case "${OSTYPE}" in
    bsd*)
      echo 'bsd'
      ;;
    darwin*)
      echo 'macos'
      ;;
    linux*)
      echo 'linux'
      ;;
    solaris*)
      echo 'solaris'
      ;;
    *)
      echo "Unknown: ${OSTYPE}"
      ;;
  esac
}

zsh::get_os_like() {
  [[ $(zsh::get_os) != 'linux' ]] && echo $(zsh::get_os) ||
  echo $(grep 'ID_LIKE=*' /etc/os-release | cut -f2- -d=)
}

# This thing is damn slow to run multiple time, better put it here
# TODO: USE EVAL CACHE for OS and LS_TYPE
export OS_NAME="$(zsh::get_os)"
export OS_LIKE="$(zsh::get_os_like)"

zsh::is_macos() {
  [[ "${OS_NAME}" == 'macos' ]]
}

zsh::is_linux() {
  [[ "${OS_NAME}" == 'linux' ]]
}

zsh::is_fun() {
  typeset -f "$1" > /dev/null
  return "$?"
}

zsh::is_set() {
  [[ -v "$1" ]]
}

zsh::is_dir() {
  [[ -d "$1" ]]
}

zsh::is_file() {
  [[ -f "$1" ]]
}

zsh::is_readable() {
  [[ -r "$1" ]]
}

zsh::is_writeable() {
  [[ -w "$1" ]]
}

zsh::not_empty() {
  [[ -f "$1" && -s "$1" ]]
}

zsh::ls_fun() {
  print -l ${(ok)functions}
}

zsh::ls_env() {
  if [[ -z "$1" ]]; then
    printenv | sort
  else
    printenv | grep --color=auto "$1.*="
  fi
}

zsh::ls_path() {
  local paths=(${(@s/:/)PATH})

  for entry in ${paths}; do
    echo "${entry}"
  done
}

zsh::path_munge() {
  if $(zsh::is_dir "$1") && $(zsh::is_readable "$1") &&
      ! echo "${PATH}" | grep -Eq "(^|:)$1($|:)"; then
    if [ "$2" = "after" ] ; then
      PATH="${PATH}:$1"
    else
      PATH="$1:${PATH}"
    fi
  fi
}
