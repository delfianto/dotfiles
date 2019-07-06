# File 10_utils.zsh; common functions used by all shell script
#
# Most of the function I wrote will have 'fn.' prefix on them
# (just my personal perference) to make them easier to identify.

# Up, the Plugin
# Author: Peter Hurford
# https://github.com/peterhurford/up.zsh
#
# Go up X directories (default 1)
up() {
  if [[ "$#" -ne 1 ]]; then
    cd ..
  elif ! [[ "$1" =~ '^[0_9]+$' ]]; then
    echo "Error: up should be called with the number of directories to go up. The default is 1."
  else
    local d=""
    limit="$1"
    for ((i=1 ; i <= limit ; i++))
      do
        d="${d}/.."
      done
    d=$(echo "${d}" | sed 's/^\///')
    cd "${d}"
  fi
}

fn.emoji() {
  if [[ "$?" == 0 ]]; then
    echo '🍄'
  else
    echo '💀'
  fi
}

fn.ls-type() {
  if $(ls --color -d "${HOME}" >/dev/null 2>&1); then
    echo 'gnu'
  elif $(ls -G -d "${HOME}" >/dev/null 2>&1); then
    echo 'bsd'
  else
    echo 'solaris'
  fi
}

fn.os-name() {
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

fn.os-like() {
  [[ $(fn.os-name) != 'linux' ]] && echo $(fn.os-name) ||
  echo $(grep 'ID_LIKE=*' /etc/os-release | cut -f2- -d=)
}

fn.has-cmd() {
  command -v "$1" &>/dev/null
  [[ "$?" == '0' ]]
}

fn.has-env() {
  env_check "${1}" &>/dev/null
  [[ "$?" == '0' ]]
}

fn.is-dir() {
  [[ -d "$1" ]]
}

fn.is-file() {
  [[ -f "$1" ]]
}

fn.is-readable() {
  [[ -r "$1" ]]
}

fn.is-writeable() {
  [[ -w "$1" ]]
}

fn.is-not-empty() {
  fn.is-file "$1" && [[ -s "$1" ]]
}

fn.is-macos() {
  [[ $(fn.os-name) == 'macos' ]]
}

fn.is-linux() {
  [[ $(fn.os-name) == 'linux' ]]
}

fn.list-fun() {
  print -l ${(ok)functions}
}

fn.list-env() {
  if [[ -z "$1" ]]; then
    printenv
  else
    printenv | grep --color=auto "$1.*="
  fi
}

fn.list-path() {
  local paths=(${(@s/:/)PATH})

  for entry in ${paths}; do
    echo "${entry}"
  done
}

fn.path_add() {
  if $(fn.is-dir "$1") && $(fn.is-readable "$1"); then
    case ":$PATH:" in
      *":${1}:"*) : ;; # already there
      *) PATH="${1}:${PATH}" ;; # or PATH="$PATH:$1"
    esac
  fi
}
