#!/bin/zsh
# File 03_macos; macos specific alias and environment variables

# Initialize homebrew stuff
export HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"

if [[ -d "${HOMEBREW_PREFIX}" && -r "${HOMEBREW_PREFIX}" ]]; then
  export LC_ALL="en_US.UTF-8"
  export HOMEBREW_GNU_UTILS="${HOMEBREW_GNU_UTILS:-1}"

  if (( "${HOMEBREW_GNU_UTILS}" )); then
    # GNU utilities and manpage
    local -a gnu_pkgs
    gnu_pkgs=(coreutils findutils gnu-indent gnu-which gnu-sed gnu-tar)

    for gnu in "${gnu_pkgs[@]}"; do
      local gnu_lib="${HOMEBREW_PREFIX}/opt/${gnu}/libexec"

      if [[ -r "${gnu_lib}" ]]; then
        add_path "${gnu_lib}/gnubin"
      fi
    done
  fi

  # Homebrew local/sbin
  add_path "${HOMEBREW_PREFIX}/sbin"

  # Ruby
  add_path "${HOMEBREW_PREFIX}/opt/ruby/bin"

  # Python
  add_path "${HOMEBREW_PREFIX}/opt/python/libexec/bin"

  # Cask options
  import "${ZDOTDIR}/private/homebrew.zsh"
  export HOMEBREW_CASK_OPTS="--appdir=/Applications"
fi

# ls enhancement
if has_cmd gls; then
  alias ls="gls ${LS_ARGS}"
  alias ll="gls ${LS_ARGS} -l"
  alias la="gls ${LS_ARGS} -a"
else
  alias ll="ls -l"
  alias la="ls -a"
fi
