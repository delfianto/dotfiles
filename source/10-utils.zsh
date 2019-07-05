# File 10_utils.zsh; common functions used by all shell script
# Most of the function I wrote will have 'zsh_' prefix on them
# (just my personal prefs) to make them easier to identify.

# Up, the Plugin
# Author: Peter Hurford
# https://github.com/peterhurford/up.zsh
#
# Go up X directories (default 1)
up() {
  if [[ "$#" -ne 1 ]]; then
    cd ..
  elif ! [[ "${1}" =~ '^[0_9]+$' ]]; then
    echo "Error: up should be called with the number of directories to go up. The default is 1."
  else
    local d=""
    limit="${1}"
    for ((i=1 ; i <= limit ; i++))
      do
        d="${d}/.."
      done
    d=$(echo "${d}" | sed 's/^\///')
    cd "${d}"
  fi
}

zsh_emoji() {
  if [[ "${?}" == 0 ]]; then
    echo '🍄'
  else
    echo '💀'
  fi
}

zsh_ls_name() {
  if $(ls --color -d "${HOME}" >/dev/null 2>&1); then
    echo 'gnu'
  elif $(ls -G -d "${HOME}" >/dev/null 2>&1); then
    echo 'bsd'
  else
    echo 'solaris'
  fi
}

zsh_os_name() {
  case "${OSTYPE}" in
  solaris*)
    echo 'Solaris'
    ;;
  darwin*)
    echo 'macOS'
    ;;
  linux*)
    echo 'Linux'
    ;;
  bsd*)
    echo 'BSD'
    ;;
  *)
    echo "Unknown: ${OSTYPE}"
    ;;
  esac
}

zsh_has_cmd() {
  command -v "${1}" &>/dev/null
  [[ ${?} == '0' ]]
}

zsh_has_env() {
  env_check "${1}" &>/dev/null
  [[ ${?} == '0' ]]
}

zsh_is_dir() {
  [[ -d "${1}" ]]
}

zsh_is_file() {
  [[ -f "${1}" ]]
}

zsh_is_readable() {
  [[ -r "${1}" ]]
}

zsh_is_writeable() {
  [[ -w "${1}" ]]
}

zsh_is_not_empty() {
  zsh_is_file "${1}" && [[ -s "${1}" ]]
}

zsh_is_macos() {
  [[ $(zsh_os_name) == 'macOS' ]]
}

zsh_is_homebrew() {
  zsh_is_macos && zsh_is_file '/usr/local/bin/brew'
}

zsh_is_linux() {
  [[ $(zsh_os_name) == 'Linux' ]]
}

zsh_is_linux_arch() {
  zsh_is_linux && zsh_has_cmd 'pacman'
}

zsh_is_linux_rhel() {
  zsh_is_linux && zsh_has_cmd 'dnf'
}

zsh_is_linux_debian() {
  zsh_is_linux && zsh_has_cmd 'apt'
}

zsh_env() {
  if [[ -z "${1}" ]]; then
    printenv
  else
    printenv | grep --color=auto "${1}.*="
  fi
}

zsh_path() {
  local paths=(${(@s/:/)PATH})

  for entry in ${paths}; do
    echo "${entry}"
  done
}

zsh_path_add() {
  if $(zsh_is_dir "${1}") && $(zsh_is_readable "${1}"); then
    case ":$PATH:" in
      *":${1}:"*) : ;; # already there
      *) PATH="${1}:${PATH}" ;; # or PATH="$PATH:$1"
    esac
  fi
}
