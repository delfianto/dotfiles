# ===========================================
# File 00_utils.zsh; common helper functions
# ===========================================

# ex - archive extractor
# usage: ex <file>
ex() {
  if [[ -f "$1" ]]; then
    case "$1" in
    *.tar.bz2) tar xjf "$1" ;;
    *.tar.gz) tar xzf "$1" ;;
    *.bz2) bunzip2 "$1" ;;
    *.rar) unrar x "$1" ;;
    *.gz) gunzip "$1" ;;
    *.tar) tar xf "$1" ;;
    *.tbz2) tar xjf "$1" ;;
    *.tgz) tar xzf "$1" ;;
    *.zip) unzip "$1" ;;
    *.Z) uncompress "$1" ;;
    *.7z) 7z x "$1" ;;
    *) echo "'$1' cannot be extracted via ex()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

exit_code() {
  if [[ "$?" -eq 0 ]]; then
    echo '🍄'
  else
    echo '💀'
  fi
}

jvm() {
  if [[ $(sys os-like) == 'arch' ]]; then
    local arch_java=$(archlinux-java get)

    if [[ -z "${arch_java}" ]]; then
      echo 'There is no defined Java VM environment on the system.'
      echo 'Run [ archlinux-java set ] to configure your system JVM.'
      return 1
    fi

    JAVA_HOME="/usr/lib/jvm/${arch_java}"

    echo "Using sytem JVM: ${arch_java}"
    "${JAVA_HOME}/bin/java" "${@:1}"
  else
    java "${@:1}"
  fi 
}

is_func() {
  typeset -f "$1" > /dev/null
  return "$?"
}

ls_func() {
  print -l ${(ok)functions}
}

ls_path() {
  echo 'path'
}

ls_vars() {
  if [[ -z "$1" ]]; then
    printenv | sort
  else
    printenv | grep --color=auto "$1.*="
  fi
}

path_munge() {
  if [[ -d "$1" ]] && [[ -r "$1" ]] && 
      ! echo "${PATH}" | grep -Eq "(^|:)$1($|:)"; then
    if [[ "$2" = 'after' ]]; then
      PATH="${PATH}:$1"
    else
      PATH="$1:${PATH}"
    fi
  fi
}
